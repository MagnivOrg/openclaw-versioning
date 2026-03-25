#!/bin/bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE="${OPENCLAW_WORKSPACE:-$HOME/.openclaw/workspace}"
HOOKS_DEST="$WORKSPACE/hooks"

# ─── Colors ──────────────────────────────────────────────────────────
RESET='\033[0m'; GRAY='\033[0;90m'; BRCYAN='\033[1;36m'; BRGREEN='\033[1;32m'
BRWHITE='\033[1;97m'; YELLOW='\033[0;33m'; RED='\033[0;31m'; DIM='\033[2m'
BRMAGENTA='\033[1;35m'

CHECK="${BRGREEN}✓${RESET}"; WARN="${YELLOW}!${RESET}"; CROSS="${RED}✗${RESET}"
ARROW="${BRCYAN}›${RESET}"

step()    { printf "  ${ARROW} %b\n" "$*"; }
success() { printf "  ${CHECK} %b\n" "$*"; }
warn()    { printf "  ${WARN} %b\n" "$*"; }
fail()    { printf "  ${CROSS} %b\n" "$*"; exit 1; }
gap()     { echo ""; }
header()  { printf "\n  ${BRCYAN}▸ %s${RESET}\n\n" "$*"; }

echo ""
printf "  ${BRMAGENTA}◆${RESET}  ${BRWHITE}agent versioning — setup${RESET}\n"
printf "  ${GRAY}version control for your openclaw workspace${RESET}\n"
gap

# ─── Prerequisites ────────────────────────────────────────────────────
header "Checking prerequisites"

command -v git &>/dev/null || fail "git not found — install it first"
success "git $(git --version | awk '{print $3}')"

[ -d "$WORKSPACE" ] || fail "Workspace not found: $WORKSPACE"
success "workspace ${GRAY}$WORKSPACE${RESET}"

command -v openclaw &>/dev/null || warn "openclaw CLI not found — you'll need to enable hooks manually"
if command -v openclaw &>/dev/null; then
  success "openclaw $(openclaw --version 2>&1 | head -1 | awk '{print $2}')"
fi

# ─── Install hooks ────────────────────────────────────────────────────
header "Installing hooks"

mkdir -p "$HOOKS_DEST"

HOOKS=("openclaw-versioning-capture" "openclaw-versioning-commit")
for hook in "${HOOKS[@]}"; do
  src="$SCRIPT_DIR/hooks/$hook"
  dest="$HOOKS_DEST/$hook"

  if [ ! -d "$src" ]; then
    warn "Hook source not found: $src"
    continue
  fi

  if [ -L "$dest" ]; then
    rm "$dest"
  elif [ -d "$dest" ]; then
    rm -rf "$dest"
  fi

  cp -r "$src" "$dest"
  success "Installed ${BRCYAN}${hook}${RESET}"
done

gap

# Enable hooks via CLI if available
if command -v openclaw &>/dev/null; then
  step "Enabling hooks..."
  for hook in "${HOOKS[@]}"; do
    if openclaw hooks enable "$hook" 2>/dev/null; then
      success "Enabled ${BRCYAN}${hook}${RESET}"
    else
      warn "Could not enable $hook — run: ${BRCYAN}openclaw hooks enable $hook${RESET}"
    fi
  done
else
  warn "Enable hooks manually:"
  for hook in "${HOOKS[@]}"; do
    printf "    ${GRAY}openclaw hooks enable %s${RESET}\n" "$hook"
  done
fi

# ─── Initialize git repo ──────────────────────────────────────────────
header "Git repository"

if [ -d "$WORKSPACE/.git" ]; then
  COMMIT_COUNT=$(cd "$WORKSPACE" && git rev-list --count HEAD 2>/dev/null || echo "0")
  success "Already initialized ${GRAY}(${COMMIT_COUNT} commits)${RESET}"
else
  (cd "$WORKSPACE" && git init -b main) >/dev/null 2>&1
  success "Initialized git repository"
fi

# Write .gitignore if missing
if [ ! -f "$WORKSPACE/.gitignore" ]; then
  cat > "$WORKSPACE/.gitignore" << 'GITIGNORE'
# Runtime data
memory/
*.log
*.jsonl
known_channels.txt
known_mention_threads.txt
.DS_Store
investigations/
.version-context
state/
state.json

# OpenClaw internal
.openclaw/
GITIGNORE
  success "Created ${BRCYAN}.gitignore${RESET}"
fi

# ─── Seed workspace config ────────────────────────────────────────────
header "Workspace config"

WORKSPACE_CFG="$WORKSPACE/.openclaw-versioning.json"
if [ ! -f "$WORKSPACE_CFG" ]; then
  cat > "$WORKSPACE_CFG" << 'EOF'
{
  "tracked": [
    "AGENTS.md",
    "SOUL.md",
    "IDENTITY.md",
    "USER.md",
    "TOOLS.md",
    "HEARTBEAT.md",
    "BOOT.md",
    "BOOTSTRAP.md",
    "MEMORY.md",
    ".gitignore",
    ".openclaw-versioning.json",
    "skills/",
    "hooks/"
  ]
}
EOF
  success "Created ${BRCYAN}.openclaw-versioning.json${RESET}"
else
  success ".openclaw-versioning.json already exists — leaving as-is"
fi

# ─── First snapshot ───────────────────────────────────────────────────
header "First snapshot"

cd "$WORKSPACE"
while IFS= read -r f; do
  git add "$f" 2>/dev/null || true
done < <(jq -r '.tracked[]?' "$WORKSPACE/.openclaw-versioning.json" 2>/dev/null)

if ! git diff --cached --quiet 2>/dev/null; then
  git commit -m "Initial snapshot — agent versioning setup" >/dev/null 2>&1
  HASH=$(git rev-parse --short HEAD)
  success "Snapshot ${BRCYAN}${HASH}${RESET} created"
else
  printf "  ${DIM}No new files to commit${RESET}\n"
fi

# ─── GitHub (optional) ────────────────────────────────────────────────
header "GitHub (optional)"

REMOTE_URL=""

printf "  Connect this repo to GitHub for remote backups? "
read -rp "[Y/n] " _github_choice
_github_choice="${_github_choice:-y}"

if [[ "$_github_choice" =~ ^[Yy] ]]; then

  if command -v gh &>/dev/null; then
    GH_USER=$(gh api user --jq '.login' 2>/dev/null || true)

    if [ -n "$GH_USER" ]; then
      success "gh CLI authenticated as ${BRCYAN}@${GH_USER}${RESET}"
      printf "  Use gh to connect a GitHub repo? "
      read -rp "[Y/n] " _use_gh
      _use_gh="${_use_gh:-y}"

      if [[ "$_use_gh" =~ ^[Yy] ]]; then
        printf "  Repo ${GRAY}(e.g. owner/repo or full URL)${RESET}: "
        read -rp "" _repo_input
        if [[ "$_repo_input" =~ ^https?:// ]] || [[ "$_repo_input" =~ ^git@ ]]; then
          REMOTE_URL="$_repo_input"
        else
          REMOTE_URL="git@github.com:${_repo_input}.git"
        fi
      fi

    else
      warn "gh CLI found but not logged in"
      printf "  Run \`gh auth login\` now? "
      read -rp "[Y/n] " _gh_login
      _gh_login="${_gh_login:-y}"

      if [[ "$_gh_login" =~ ^[Yy] ]]; then
        gh auth login
        GH_USER=$(gh api user --jq '.login' 2>/dev/null || true)
        if [ -n "$GH_USER" ]; then
          success "Authenticated as ${BRCYAN}@${GH_USER}${RESET}"
          printf "  Repo ${GRAY}(e.g. owner/repo or full URL)${RESET}: "
          read -rp "" _repo_input
          if [[ "$_repo_input" =~ ^https?:// ]] || [[ "$_repo_input" =~ ^git@ ]]; then
            REMOTE_URL="$_repo_input"
          else
            REMOTE_URL="git@github.com:${_repo_input}.git"
          fi
        else
          warn "Auth did not complete — falling back to manual URL entry"
        fi
      fi
    fi
  fi

  # No gh, or user declined — prompt for URL manually
  if [ -z "$REMOTE_URL" ]; then
    printf "  Remote URL ${GRAY}(e.g. git@github.com:owner/repo.git)${RESET}: "
    read -rp "" REMOTE_URL
  fi

  if [ -n "$REMOTE_URL" ]; then
    cd "$WORKSPACE"
    if git remote get-url origin &>/dev/null 2>&1; then
      git remote set-url origin "$REMOTE_URL"
      success "Updated remote origin → ${GRAY}${REMOTE_URL}${RESET}"
    else
      git remote add origin "$REMOTE_URL"
      success "Added remote origin → ${GRAY}${REMOTE_URL}${RESET}"
    fi

    # Persist git remote into workspace config
    WORKSPACE_CFG="$WORKSPACE/.openclaw-versioning.json"
    if command -v jq &>/dev/null; then
      TMP=$(mktemp)
      jq --arg remote "$REMOTE_URL" '.git.remote = $remote | .git.branch = "main"' \
        "$WORKSPACE_CFG" > "$TMP" && mv "$TMP" "$WORKSPACE_CFG"
    else
      python3 - "$WORKSPACE_CFG" "$REMOTE_URL" <<'PYEOF'
import json, sys
path, remote = sys.argv[1], sys.argv[2]
with open(path) as f: cfg = json.load(f)
cfg.setdefault("git", {})
cfg["git"]["remote"] = remote
cfg["git"]["branch"] = "main"
with open(path, "w") as f: json.dump(cfg, f, indent=2)
PYEOF
    fi
    success "Saved git config to ${BRCYAN}.openclaw-versioning.json${RESET}"

    # Initial push
    step "Pushing to origin..."
    if git push -u origin main 2>/dev/null; then
      success "Initial push complete"
    else
      warn "Push failed — run ${BRCYAN}git push -u origin main${RESET} after verifying auth"
    fi
  fi

else
  printf "  ${DIM}Skipped — add a remote later with \`git remote add origin <url>\`${RESET}\n"
fi

# ─── Done ─────────────────────────────────────────────────────────────
gap
printf "  ${GRAY}────────────────────────────────────────────────${RESET}\n"
printf "  ${BRGREEN}✓  agent versioning is active${RESET}\n"
printf "  ${GRAY}────────────────────────────────────────────────${RESET}\n"
gap
printf "  ${GRAY}Restart the openclaw gateway to load the hooks, then${RESET}\n"
printf "  ${GRAY}say ${BRCYAN}/openclaw-versioning setup${GRAY} to finish cron registration.${RESET}\n"
gap
printf "  ${GRAY}Commands (say these to your agent):${RESET}\n"
printf "  ${BRCYAN}/openclaw-versioning setup${RESET}\n"
printf "  ${BRCYAN}/openclaw-versioning status${RESET}\n"
printf "  ${BRCYAN}/openclaw-versioning log${RESET}\n"
printf "  ${BRCYAN}/openclaw-versioning diff${RESET} ${DIM}<hash>${RESET}\n"
printf "  ${BRCYAN}/openclaw-versioning rollback${RESET} ${DIM}<hash>${RESET}\n"
printf "  ${BRCYAN}/openclaw-versioning snapshot${RESET} ${DIM}\"description\"${RESET}\n"
printf "  ${BRCYAN}/openclaw-versioning commit${RESET}\n"
gap
