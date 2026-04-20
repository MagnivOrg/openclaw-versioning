#!/usr/bin/env node
'use strict';

const fs = require('fs');
const os = require('os');
const path = require('path');
const { execSync } = require('child_process');

const WORKSPACE = process.env.OPENCLAW_WORKSPACE || path.join(process.env.HOME, '.openclaw/workspace');
const OPENCLAW_CONFIG = process.env.OPENCLAW_CONFIG || path.join(os.homedir(), '.openclaw', 'openclaw.json');
const BASE_URL = 'https://api.promptlayer.com';
const SNAPSHOT_PATH = 'snapshot.zip';

function loadOpenClawConfig() {
  try {
    const raw = fs.readFileSync(OPENCLAW_CONFIG, 'utf8');
    return JSON.parse(raw);
  } catch (err) {
    if (err && err.code === 'ENOENT') return {};
    console.error(`OpenClaw config is invalid or unreadable: ${OPENCLAW_CONFIG}`);
    process.exit(1);
  }
}

function getSkillEntry(config) {
  return config?.skills?.entries?.['agent-changelog'] || {};
}

function buildSnapshotZip() {
  const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'agent-changelog-'));
  const zipPath = path.join(tmpDir, 'snapshot.zip');
  try {
    execSync(`git archive --format=zip -o ${JSON.stringify(zipPath)} HEAD`, { cwd: WORKSPACE });
    return fs.readFileSync(zipPath);
  } finally {
    fs.rmSync(tmpDir, { recursive: true, force: true });
  }
}

async function main() {
  const args = process.argv.slice(2);
  let commitMessage = '';
  let releaseLabel = '';
  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--message' && args[i + 1]) commitMessage = args[++i];
    if (args[i] === '--label' && args[i + 1]) releaseLabel = args[++i];
  }

  const openclawConfig = loadOpenClawConfig();
  const skillEntry = getSkillEntry(openclawConfig);
  const pl = skillEntry.promptlayer || {};

  if (!pl?.enabled || !pl.collectionId) return;

  const apiKeyValue = skillEntry.apiKey?.value || '';
  if (!apiKeyValue) return;

  const statusLines = execSync('git diff-tree --no-commit-id -r --name-status HEAD', { cwd: WORKSPACE })
    .toString().trim().split('\n').filter(Boolean);

  if (statusLines.length === 0) return;

  if (!commitMessage) {
    commitMessage = execSync('git log -1 --pretty=%s', { cwd: WORKSPACE }).toString().trim();
  }

  const zipBuffer = buildSnapshotZip();
  const metadataObj = { commit_message: commitMessage };
  if (releaseLabel) metadataObj.release_label = releaseLabel;
  const form = new FormData();
  form.append('metadata', JSON.stringify(metadataObj));
  form.append('zip', new Blob([zipBuffer], { type: 'application/zip' }), 'snapshot.zip');

  const res = await fetch(
    `${BASE_URL}/api/public/v2/skill-collections/${pl.collectionId}/versions`,
    {
      method: 'POST',
      headers: { 'X-API-KEY': apiKeyValue },
      body: form,
    }
  );

  if (!res.ok) {
    const err = await res.text();
    process.stderr.write(`⚠️  PromptLayer sync failed (${res.status}): ${err}\n`);
    process.exit(1);
  }

  const result = await res.json();
  process.stdout.write(`↑ PromptLayer v${result.version?.number ?? '?'}\n`);
}

main().catch(e => { process.stderr.write(`⚠️  PromptLayer: ${e.message}\n`); process.exit(1); });
