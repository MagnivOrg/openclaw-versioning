#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const WORKSPACE = process.env.OPENCLAW_WORKSPACE || path.join(process.env.HOME, '.openclaw/workspace');
const CONFIG_PATH = path.join(WORKSPACE, '.agent-changelog.json');
const BASE_URL = 'https://api.promptlayer.com';

async function main() {
  const config = JSON.parse(fs.readFileSync(CONFIG_PATH, 'utf8'));
  const pl = config.promptlayer;

  if (!pl?.enabled) {
    console.error('PromptLayer not configured in .agent-changelog.json');
    process.exit(1);
  }

  if (pl.collectionId) {
    console.log(`Already connected: ${pl.collectionId}`);
    return;
  }

  const apiKey = process.env[pl.apiKeyEnvVar || 'PROMPTLAYER_API_KEY'];
  if (!apiKey) {
    console.error(`Missing env var: ${pl.apiKeyEnvVar || 'PROMPTLAYER_API_KEY'}`);
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
    headers: { 'X-API-KEY': apiKey, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      name: pl.skillName,
      provider: pl.provider || 'openclaw',
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

  config.promptlayer.collectionId = skill_collection.id;
  config.sync = { ...(config.sync || {}), provider: 'promptlayer' };
  fs.writeFileSync(CONFIG_PATH, JSON.stringify(config, null, 2) + '\n');

  console.log(`✅ Collection "${skill_collection.name}" created (${skill_collection.id})`);
}

main().catch(e => { console.error(e.message); process.exit(1); });
