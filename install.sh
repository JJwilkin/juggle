#!/usr/bin/env bash
# Juggle installer — downloads and installs all files directly from GitHub
# Usage: curl -fsSL https://raw.githubusercontent.com/JJwilkin/juggle-task/main/install.sh | bash
#
# Options (set as env vars before piping):
#   JUGGLE_VERSION   pin a specific tag/branch (default: main)
#   JUGGLE_BIN_DIR   where to install the jt CLI (default: ~/.local/bin)

set -euo pipefail

REPO="JJwilkin/juggle-task"
VERSION="${JUGGLE_VERSION:-main}"
RAW_BASE="https://raw.githubusercontent.com/${REPO}/${VERSION}"
CLAUDE_SKILLS_DIR="${HOME}/.claude/skills"
CODEX_SKILLS_DIR="${CODEX_HOME:-${HOME}/.codex}/skills"
BIN_DIR="${JUGGLE_BIN_DIR:-${HOME}/.local/bin}"
JT_CONFIG="${HOME}/.jt-config"
DEFAULT_TICKETS_DIR="${HOME}/juggle-task"
SKILLS=(jt-init jt-update jt-project-init jt-sync)

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()    { echo -e "${GREEN}✓${NC} $*"; }
warning() { echo -e "${YELLOW}!${NC} $*"; }
error()   { echo -e "${RED}✗${NC} $*" >&2; exit 1; }

# Check for curl
command -v curl >/dev/null 2>&1 || error "curl is required but not installed."

download() {
  local url="$1"
  local dest="$2"
  mkdir -p "$(dirname "$dest")"
  curl -fsSL "$url" -o "$dest" || error "Failed to download: $url"
}

echo ""
echo "Installing Juggle v${VERSION}..."
echo ""

# 1. Install skills into BOTH Claude and Codex skill directories (if their
# parent .claude / .codex dir exists or the CLI is installed). Skills are
# engine-agnostic: they detect CLAUDE_CODE_SESSION_ID vs CODEX_THREAD_ID at
# runtime and use the right session file format for each engine.
install_skills_for_engine() {
  local label="$1" target_dir="$2" parent
  parent="$(dirname "$target_dir")"
  if [[ ! -d "$parent" ]]; then
    warning "$label home not found at $parent — skipping (install $label first to enable)"
    return 0
  fi
  for skill in "${SKILLS[@]}"; do
    local dest="${target_dir}/${skill}/SKILL.md"
    download "${RAW_BASE}/skills/${skill}/SKILL.md" "$dest"
    info "$label skill installed:  $dest"
  done
}

install_skills_for_engine "Claude" "$CLAUDE_SKILLS_DIR"
install_skills_for_engine "Codex"  "$CODEX_SKILLS_DIR"

# 2. Install jt CLI
jt_dest="${BIN_DIR}/jt"
download "${RAW_BASE}/bin/jt" "$jt_dest"
chmod +x "$jt_dest"
info "CLI installed:     $jt_dest"

# 3. Add ~/.local/bin to PATH if needed
add_to_path() {
  local rc_file="$1"
  local path_line='export PATH="$HOME/.local/bin:$PATH"'
  [[ ! -f "$rc_file" ]] && return 0
  grep -q '\.local/bin' "$rc_file" && return 0
  printf '\n# juggle (jt)\n%s\n' "$path_line" >> "$rc_file"
  info "Added ~/.local/bin to PATH in $rc_file"
}

if [[ ":$PATH:" != *":${HOME}/.local/bin:"* ]]; then
  add_to_path "${HOME}/.zshrc"
  add_to_path "${HOME}/.bashrc"
  warning "~/.local/bin added to PATH. Run: export PATH=\"\$HOME/.local/bin:\$PATH\""
fi

# 4. Create default config and tickets dir if not already set
if [[ ! -f "$JT_CONFIG" ]]; then
  echo "$DEFAULT_TICKETS_DIR" > "$JT_CONFIG"
  mkdir -p "$DEFAULT_TICKETS_DIR"
  info "Tickets directory: $DEFAULT_TICKETS_DIR"
  info "Config:            $JT_CONFIG"
else
  existing=$(cat "$JT_CONFIG")
  info "Config exists:     $existing (unchanged)"
fi

echo ""
echo "Juggle installed successfully."
echo ""
echo "Next steps:"
echo "  1. Restart Claude Code and/or Codex to load the new skills"
echo "  2. Run /jt-init <ticket-id> inside Claude Code or Codex to create your first ticket"
echo "  3. Run 'jt help' in your terminal for CLI usage"
echo "  4. (Optional) 'jt engine set claude|codex' to pin a default engine"
echo ""
echo "Docs: https://github.com/JJwilkin/juggle-task"
