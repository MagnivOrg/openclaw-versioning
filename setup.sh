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

# ─── Register cron ────────────────────────────────────────────────
header "Registering cron"

if command -v openclaw &>/dev/null; then
  CRON_NAME="openclaw-versioning-commit"
  CRON_CMD="bash $SCRIPT_DIR/scripts/commit.sh"
  if openclaw cron add --name "$CRON_NAME" --schedule "*/10 * * * *" --message "$CRON_CMD" --session isolated 2>/dev/null; then
    success "Registered ${BRCYAN}${CRON_NAME}${RESET} (every 10 min)"
  else
    warn "Cron may already be registered, or registration failed — check with: ${BRCYAN}openclaw cron list${RESET}"
  fi
else
  warn "Register cron manually after gateway starts:"
  printf "    ${GRAY}openclaw cron add --name openclaw-versioning-commit --schedule '*/10 * * * *' --message 'bash %s/scripts/commit.sh' --session isolated${RESET}\n" "$SCRIPT_DIR"
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

# ─── Done ─────────────────────────────────────────────────────────────
gap
printf "  ${GRAY}────────────────────────────────────────────────${RESET}\n"
printf "  ${BRGREEN}✓  agent versioning is active${RESET}\n"
printf "  ${GRAY}────────────────────────────────────────────────${RESET}\n"
gap
printf "  ${BRWHITE}Next steps:${RESET}\n"
gap
printf "  ${BRCYAN}1.${RESET} Restart the openclaw gateway\n"
printf "  ${BRCYAN}2.${RESET} Say ${BRCYAN}/openclaw-versioning status${RESET} to verify\n"
gap
printf "  ${BRWHITE}To push commits to a remote:${RESET}\n"
printf "  ${DIM}# set up auth first (gh auth login, SSH key, or HTTPS token)${RESET}\n"
printf "  ${DIM}cd %s${RESET}\n" "$WORKSPACE"
printf "  ${DIM}git remote add origin <url>${RESET}\n"
printf "  ${DIM}# then add to .openclaw-versioning.json:${RESET}\n"
printf "  ${DIM}# \"git\": { \"remote\": \"origin\", \"branch\": \"main\" }${RESET}\n"
gap
printf "  ${BRWHITE}Commands (say these to your agent):${RESET}\n"
printf "  ${BRCYAN}/openclaw-versioning status${RESET}\n"
printf "  ${BRCYAN}/openclaw-versioning log${RESET}\n"
printf "  ${BRCYAN}/openclaw-versioning diff${RESET} ${DIM}<hash>${RESET}\n"
printf "  ${BRCYAN}/openclaw-versioning rollback${RESET} ${DIM}<hash>${RESET}\n"
printf "  ${BRCYAN}/openclaw-versioning restore${RESET} ${DIM}<file> <hash>${RESET}\n"
printf "  ${BRCYAN}/openclaw-versioning snapshot${RESET} ${DIM}\"description\"${RESET}\n"
printf "  ${BRCYAN}/openclaw-versioning commit${RESET}\n"
gap
