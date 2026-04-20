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

function saveOpenClawConfig(config) {
  fs.mkdirSync(path.dirname(OPENCLAW_CONFIG), { recursive: true });
  fs.writeFileSync(OPENCLAW_CONFIG, JSON.stringify(config, null, 2) + '\n');
}

function getSkillEntry(config) {
  return config?.skills?.entries?.['agent-changelog'] || {};
}

function setSkillEntry(config, entry) {
  if (!config.skills) config.skills = {};
  if (!config.skills.entries) config.skills.entries = {};
  config.skills.entries['agent-changelog'] = entry;
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
  let skillNameArg = '';
  let providerArg = '';
  let apiKeyArg = '';

  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--name' && args[i + 1]) skillNameArg = args[++i];
    if (args[i] === '--provider' && args[i + 1]) providerArg = args[++i];
    if (args[i] === '--api-key' && args[i + 1]) apiKeyArg = args[++i];
  }

  const openclawConfig = loadOpenClawConfig();
  const skillEntry = getSkillEntry(openclawConfig);
  const pl = skillEntry.promptlayer || {};
  const skillName = skillNameArg || pl.skillName || '';
  const provider = providerArg || pl.provider || 'openclaw';
  const existingApiKey = skillEntry.apiKey?.value || '';
  const apiKeyValue = apiKeyArg || existingApiKey;

  if (pl.collectionId) {
    const nextApiKey = apiKeyValue ? { value: apiKeyValue } : skillEntry.apiKey;
    const updatedSkillEntry = {
      ...skillEntry,
      sync: { ...(skillEntry.sync || {}), provider: 'promptlayer' },
      promptlayer: {
        enabled: true,
        skillName: skillName || pl.skillName || '',
        collectionId: pl.collectionId,
        provider,
      },
    };
    if (nextApiKey) updatedSkillEntry.apiKey = nextApiKey;
    setSkillEntry(openclawConfig, updatedSkillEntry);
    saveOpenClawConfig(openclawConfig);
    if (!apiKeyValue) {
      console.error('Missing API key. Save it in OpenClaw config.');
    }
    console.log(`Already connected: ${pl.collectionId}`);
    return;
  }

  if (!skillName) {
    console.error('Missing skill collection name. Pass --name or set skills.entries.agent-changelog.promptlayer.skillName in openclaw.json');
    process.exit(1);
  }

  if (!apiKeyValue) {
    console.error('Missing API key. Save it in OpenClaw config.');
    process.exit(1);
  }

  const zipBuffer = buildSnapshotZip();
  const form = new FormData();
  form.append('name', skillName);
  form.append('provider', provider);
  form.append('commit_message', 'Initial snapshot — agent versioning setup');
  form.append('files', new Blob([zipBuffer], { type: 'application/zip' }), SNAPSHOT_PATH);

  const res = await fetch(`${BASE_URL}/api/public/v2/skill-collections`, {
    method: 'POST',
    headers: { 'X-API-KEY': apiKeyValue },
    body: form,
  });

  if (!res.ok) {
    const err = await res.text();
    console.error(`PromptLayer API error ${res.status}: ${err}`);
    process.exit(1);
  }

  const { skill_collection } = await res.json();

  const updatedSkillEntry = {
    ...skillEntry,
    sync: { ...(skillEntry.sync || {}), provider: 'promptlayer' },
    promptlayer: {
      enabled: true,
      skillName,
      collectionId: skill_collection.id,
      provider,
    },
  };
  updatedSkillEntry.apiKey = { value: apiKeyValue };
  setSkillEntry(openclawConfig, updatedSkillEntry);
  saveOpenClawConfig(openclawConfig);

  console.log(`✅ Collection "${skill_collection.name}" created (${skill_collection.id})`);
}

main().catch(e => { console.error(e.message); process.exit(1); });
