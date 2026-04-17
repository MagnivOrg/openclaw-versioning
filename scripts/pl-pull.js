#!/usr/bin/env node
'use strict';

const fs = require('fs');
const os = require('os');
const path = require('path');
const { execSync } = require('child_process');

const WORKSPACE = process.env.OPENCLAW_WORKSPACE || path.join(process.env.HOME, '.openclaw/workspace');
const OPENCLAW_CONFIG = process.env.OPENCLAW_CONFIG || path.join(os.homedir(), '.openclaw', 'openclaw.json');
const BASE_URL = 'https://api.promptlayer.com';
const SNAPSHOT_PATH = '.promptlayer/snapshot.zip.b64';

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

function listFiles(rootDir) {
  const results = [];
  const stack = [rootDir];
  while (stack.length) {
    const current = stack.pop();
    const entries = fs.readdirSync(current, { withFileTypes: true });
    for (const entry of entries) {
      const abs = path.join(current, entry.name);
      if (entry.isDirectory()) {
        stack.push(abs);
      } else if (entry.isFile()) {
        const rel = path.relative(rootDir, abs).split(path.sep).join('/');
        results.push(rel);
      }
    }
  }
  return results;
}

function extractSnapshot(snapshotBase64) {
  const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'agent-changelog-'));
  const zipPath = path.join(tmpDir, 'snapshot.zip');
  const extractDir = path.join(tmpDir, 'extract');
  try {
    fs.writeFileSync(zipPath, Buffer.from(snapshotBase64, 'base64'));
    fs.mkdirSync(extractDir, { recursive: true });
    if (process.platform === 'win32') {
      const psZip = zipPath.replace(/'/g, "''");
      const psDest = extractDir.replace(/'/g, "''");
      execSync(
        `powershell -NoProfile -Command "Expand-Archive -LiteralPath '${psZip}' -DestinationPath '${psDest}' -Force"`
      );
    } else {
      execSync(`unzip -o ${JSON.stringify(zipPath)} -d ${JSON.stringify(extractDir)}`);
    }
    const snapshotFiles = listFiles(extractDir);
    const snapshotSet = new Set(snapshotFiles);
    const trackedFiles = execSync('git ls-files', { cwd: WORKSPACE })
      .toString().trim().split('\n').filter(Boolean);

    for (const filePath of trackedFiles) {
      if (!snapshotSet.has(filePath)) {
        fs.rmSync(path.join(WORKSPACE, filePath), { force: true });
      }
    }

    for (const filePath of snapshotFiles) {
      const src = path.join(extractDir, filePath);
      const dest = path.join(WORKSPACE, filePath);
      fs.mkdirSync(path.dirname(dest), { recursive: true });
      fs.copyFileSync(src, dest);
    }
    return snapshotFiles;
  } catch {
    console.error('Failed to extract PromptLayer snapshot. Ensure unzip (mac/Linux) or Expand-Archive (Windows) is available.');
    process.exit(1);
  } finally {
    fs.rmSync(tmpDir, { recursive: true, force: true });
  }
}

async function main() {
  const args = process.argv.slice(2);
  let version = null;
  let label = null;
  let connectIdentifier = null;
  let reason = '';
  let force = false;

  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--version' && args[i + 1]) version = args[++i];
    if (args[i] === '--label' && args[i + 1]) label = args[++i];
    if (args[i] === '--connect' && args[i + 1]) connectIdentifier = args[++i];
    if (args[i] === '--reason' && args[i + 1]) reason = args[++i];
    if (args[i] === '--force') force = true;
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

  const dirty = execSync('git status --porcelain', { cwd: WORKSPACE }).toString().trim();
  if (dirty && !force) {
    console.error('Local changes detected. Confirm overwrite and re-run with --force.');
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
  const versionNumber = versionInfo?.number ?? 'latest';
  const versionLabel = label || versionInfo?.release_label || '';

  const snapshotBase64 = files?.[SNAPSHOT_PATH] || '';
  if (!snapshotBase64) {
    console.error('PromptLayer snapshot missing.');
    process.exit(1);
  }

  const snapshotFiles = extractSnapshot(snapshotBase64);

  if (connectIdentifier) {
    // Setup mode: update config, skip pending_commits
    const nextApiKey = apiKeyValue ? { value: apiKeyValue } : skillEntry.apiKey;
    const updatedSkillEntry = {
      ...skillEntry,
      sync: { ...(skillEntry.sync || {}), provider: 'promptlayer' },
      promptlayer: {
        enabled: true,
        skillName: skill_collection.name,
        collectionId: skill_collection.id,
        provider: skill_collection.provider || 'openclaw',
      },
    };
    if (nextApiKey) updatedSkillEntry.apiKey = nextApiKey;
    setSkillEntry(openclawConfig, updatedSkillEntry);
    saveOpenClawConfig(openclawConfig);
    console.log(`✅ Connected "${skill_collection.name}" (${skill_collection.id}) — pulled ${snapshotFiles.length} files from v${versionNumber}`);
    return;
  }

  const trackedFiles = execSync('git ls-files', { cwd: WORKSPACE })
    .toString().trim().split('\n').filter(Boolean);
  for (const filePath of trackedFiles) {
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
    files: snapshotFiles,
  };

  fs.appendFileSync(path.join(WORKSPACE, 'pending_commits.jsonl'), JSON.stringify(entry) + '\n');

  const versionStr = versionLabel ? `v${versionNumber} (${versionLabel})` : `v${versionNumber}`;
  console.log(`⬇️  **Pulled** ${versionStr} — ${snapshotFiles.length} file(s) staged`);
  console.log(`_by ${actor}_`);
  console.log(`Commit with \`/agent-changelog commit\``);
}

main().catch(e => { console.error(e.message); process.exit(1); });
