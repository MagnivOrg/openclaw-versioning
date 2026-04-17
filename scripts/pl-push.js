#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const WORKSPACE = process.env.OPENCLAW_WORKSPACE || path.join(process.env.HOME, '.openclaw/workspace');
const CONFIG_PATH = path.join(WORKSPACE, '.agent-changelog.json');
const BASE_URL = 'https://api.promptlayer.com';

async function main() {
  const args = process.argv.slice(2);
  let commitMessage = '';
  let releaseLabel = '';
  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--message' && args[i + 1]) commitMessage = args[++i];
    if (args[i] === '--label' && args[i + 1]) releaseLabel = args[++i];
  }

  const config = JSON.parse(fs.readFileSync(CONFIG_PATH, 'utf8'));
  const pl = config.promptlayer;

  if (!pl?.enabled || !pl.collectionId) return;

  const apiKey = process.env[pl.apiKeyEnvVar || 'PROMPTLAYER_API_KEY'];
  if (!apiKey) return;

  const statusLines = execSync('git diff-tree --no-commit-id -r --name-status HEAD', { cwd: WORKSPACE })
    .toString().trim().split('\n').filter(Boolean);

  if (statusLines.length === 0) return;

  if (!commitMessage) {
    commitMessage = execSync('git log -1 --pretty=%s', { cwd: WORKSPACE }).toString().trim();
  }

  const file_updates = [];
  const deletes = [];

  for (const line of statusLines) {
    const [status, filePath] = line.split('\t');
    if (status.startsWith('D')) {
      deletes.push(filePath);
    } else {
      try {
        const content = fs.readFileSync(path.join(WORKSPACE, filePath), 'utf8');
        file_updates.push({ path: filePath, content });
      } catch {
        // skip binary or unreadable files
      }
    }
  }

  const body = { commit_message: commitMessage, file_updates };
  if (deletes.length) body.deletes = deletes;
  if (releaseLabel) body.release_label = releaseLabel;

  const res = await fetch(
    `${BASE_URL}/api/public/v2/skill-collections/${pl.collectionId}/versions`,
    {
      method: 'POST',
      headers: { 'X-API-KEY': apiKey, 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
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
