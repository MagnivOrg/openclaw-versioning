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
  let version = null;
  let label = null;
  let connectIdentifier = null;
  let reason = '';

  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--version' && args[i + 1]) version = args[++i];
    if (args[i] === '--label' && args[i + 1]) label = args[++i];
    if (args[i] === '--connect' && args[i + 1]) connectIdentifier = args[++i];
    if (args[i] === '--reason' && args[i + 1]) reason = args[++i];
  }

  const openclawConfig = loadOpenClawConfig();
  const skillEntry = getSkillEntry(openclawConfig);
  const pl = skillEntry.promptlayer || {};
  const apiKeyValue = skillEntry.apiKey?.value || '';

  if (!apiKeyValue) {
    console.error('Missing API key. Save it in OpenClaw config.');
    process.exit(1);
  }

  const identifier = connectIdentifier || pl?.collectionId;
  if (!identifier) {
    console.error('No PromptLayer collection configured. Run setup first.');
    process.exit(1);
  }

  const params = new URLSearchParams();
  if (version) params.set('version', version);
  if (label) params.set('label', label);
  const query = params.toString() ? `?${params}` : '';

  const res = await fetch(
    `${BASE_URL}/api/public/v2/skill-collections/${encodeURIComponent(identifier)}${query}`,
    { headers: { 'X-API-KEY': apiKeyValue } }
  );

  if (!res.ok) {
    const err = await res.text();
    console.error(`PromptLayer API error ${res.status}: ${err}`);
    process.exit(1);
  }

  const { skill_collection, files, version: versionInfo } = await res.json();
  const fileList = Object.keys(files || {});
  const versionNumber = versionInfo?.number ?? 'latest';
  const versionLabel = label || versionInfo?.release_label || '';

  for (const [filePath, content] of Object.entries(files || {})) {
    const abs = path.join(WORKSPACE, filePath);
    fs.mkdirSync(path.dirname(abs), { recursive: true });
    fs.writeFileSync(abs, content, 'utf8');
  }

  if (connectIdentifier) {
    // Setup mode: update config, skip pending_commits
    const updatedSkillEntry = {
      ...skillEntry,
      sync: { ...(skillEntry.sync || {}), provider: 'promptlayer' },
      promptlayer: {
        enabled: true,
        skillName: skill_collection.name,
        collectionId: skill_collection.id,
        provider: skill_collection.provider || 'openclaw',
      },
      apiKey: {
        provider: 'promptlayer',
        value: apiKeyValue,
      },
    };
    setSkillEntry(openclawConfig, updatedSkillEntry);
    saveOpenClawConfig(openclawConfig);
    console.log(`✅ Connected "${skill_collection.name}" (${skill_collection.id}) — pulled ${fileList.length} files from v${versionNumber}`);
    return;
  }

  // User-triggered: stage files
  for (const filePath of fileList) {
    try {
      execSync(`git add ${JSON.stringify(filePath)}`, { cwd: WORKSPACE });
    } catch { /* skip unstage-able paths */ }
  }

  const staged = execSync('git diff --cached --name-only', { cwd: WORKSPACE }).toString().trim();
  if (!staged) {
    console.log('✓ Already up to date');
    return;
  }

  // Read actor from .version-context (same pattern as rollback.sh)
  let actor = 'skill invocation', actorId = 'skill invocation', channel = 'unknown';
  try {
    const ctx = JSON.parse(fs.readFileSync(path.join(WORKSPACE, '.version-context'), 'utf8'));
    actor = ctx.user || actor;
    actorId = ctx.userId || actorId;
    channel = ctx.channel || channel;
  } catch { /* no active context */ }

  const entry = {
    ts: Date.now(),
    user: actor,
    userId: actorId,
    channel,
    action: 'pl-pull',
    target: String(versionNumber),
    from: versionLabel,
    reason,
    files: fileList,
  };

  fs.appendFileSync(path.join(WORKSPACE, 'pending_commits.jsonl'), JSON.stringify(entry) + '\n');

  const versionStr = versionLabel ? `v${versionNumber} (${versionLabel})` : `v${versionNumber}`;
  console.log(`⬇️  **Pulled** ${versionStr} — ${fileList.length} file(s) staged`);
  console.log(`_by ${actor}_`);
  console.log(`Commit with \`/agent-changelog commit\``);
}

main().catch(e => { console.error(e.message); process.exit(1); });
