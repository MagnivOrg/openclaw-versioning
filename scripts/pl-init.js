#!/usr/bin/env node
'use strict';

const fs = require('fs');
const os = require('os');
const path = require('path');
const { execSync } = require('child_process');

const WORKSPACE = process.env.OPENCLAW_WORKSPACE || path.join(process.env.HOME, '.openclaw/workspace');
const OPENCLAW_CONFIG = process.env.OPENCLAW_CONFIG || path.join(os.homedir(), '.openclaw', 'openclaw.json');
const BASE_URL = 'https://api.promptlayer.com';

function loadOpenClawConfig() {
  try {
    return JSON.parse(fs.readFileSync(OPENCLAW_CONFIG, 'utf8'));
  } catch {
    return {};
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
  const apiKeyValue = apiKeyArg || skillEntry.apiKey?.value || '';

  if (pl.collectionId) {
    const updatedSkillEntry = {
      ...skillEntry,
      sync: { ...(skillEntry.sync || {}), provider: 'promptlayer' },
      promptlayer: {
        enabled: true,
        skillName: skillName || pl.skillName || '',
        collectionId: pl.collectionId,
        provider,
      },
      apiKey: {
        provider: 'promptlayer',
        value: apiKeyValue,
      },
    };
    setSkillEntry(openclawConfig, updatedSkillEntry);
    saveOpenClawConfig(openclawConfig);
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

  const fileList = execSync('git ls-files', { cwd: WORKSPACE })
    .toString().trim().split('\n').filter(Boolean);

  const files = fileList.flatMap(relativePath => {
    try {
      const content = fs.readFileSync(path.join(WORKSPACE, relativePath), 'utf8');
      return [{ path: relativePath, content }];
    } catch {
      return [];
    }
  });

  const res = await fetch(`${BASE_URL}/api/public/v2/skill-collections`, {
    method: 'POST',
      headers: { 'X-API-KEY': apiKeyValue, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      name: skillName,
      provider,
      commit_message: 'Initial snapshot — agent versioning setup',
      files,
    }),
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
    apiKey: {
      provider: 'promptlayer',
      value: apiKeyValue,
    },
  };
  setSkillEntry(openclawConfig, updatedSkillEntry);
  saveOpenClawConfig(openclawConfig);

  console.log(`✅ Collection "${skill_collection.name}" created (${skill_collection.id})`);
}

main().catch(e => { console.error(e.message); process.exit(1); });
