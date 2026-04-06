#!/bin/bash
#
# Gesso /gesso-build skill installer.
#
# Usage:
#   curl -sL https://gesso.so/skill | bash
#
# Installs the /gesso-build Claude Code skill into ~/.claude/skills/gesso-build.
# Safe to run multiple times — re-running will overwrite the existing SKILL.md
# with the latest version from the canonical GitHub repo.
#
# What this does:
#   1. Creates ~/.claude/skills/gesso-build if it doesn't exist
#   2. Downloads the latest SKILL.md from the public repo
#   3. Writes it to ~/.claude/skills/gesso-build/SKILL.md
#
# The skill is loaded by Claude Code the next time you run it. Trigger it with
# `/gesso-build`.

set -e

SKILL_DIR="$HOME/.claude/skills/gesso-build"
SKILL_URL="https://raw.githubusercontent.com/JoshRasberry/gesso-public/main/SKILL.md"

# ANSI colors — fall back to plain text if not a TTY
if [ -t 1 ]; then
  BOLD=$'\033[1m'
  GREEN=$'\033[32m'
  YELLOW=$'\033[33m'
  RED=$'\033[31m'
  DIM=$'\033[2m'
  RESET=$'\033[0m'
else
  BOLD=""
  GREEN=""
  YELLOW=""
  RED=""
  DIM=""
  RESET=""
fi

echo ""
echo "${BOLD}Installing /gesso-build skill...${RESET}"
echo ""

# Sanity check: curl must be available. Installer uses it and the skill calls it
# internally too. If curl is missing, the user needs to install it before using Gesso.
if ! command -v curl >/dev/null 2>&1; then
  echo "${RED}✗ curl is required but not installed.${RESET}"
  echo "  Install curl first, then re-run this command."
  exit 1
fi

# Create the skill directory. `mkdir -p` is idempotent — safe if the directory
# already exists from a previous install.
mkdir -p "$SKILL_DIR"

# Download the SKILL.md. -sS = silent with errors shown, -L = follow redirects,
# --fail = exit non-zero on HTTP errors. We use a temp file so a partial download
# doesn't corrupt an existing valid install.
TMP_FILE="$(mktemp)"
trap 'rm -f "$TMP_FILE"' EXIT

if ! curl -sSL --fail "$SKILL_URL" -o "$TMP_FILE"; then
  echo "${RED}✗ Failed to download SKILL.md from:${RESET}"
  echo "  $SKILL_URL"
  echo ""
  echo "  Check your internet connection and try again. If the problem persists,"
  echo "  the canonical repo may be temporarily unavailable."
  exit 1
fi

# Validate the download is non-empty and looks like a SKILL file (has frontmatter)
if [ ! -s "$TMP_FILE" ]; then
  echo "${RED}✗ Downloaded SKILL.md is empty.${RESET}"
  exit 1
fi

if ! head -n 1 "$TMP_FILE" | grep -q '^---$'; then
  echo "${YELLOW}⚠ Downloaded file doesn't look like a valid SKILL file.${RESET}"
  echo "  Expected to find YAML frontmatter (--- on the first line)."
  echo "  Proceeding anyway, but Claude Code may not recognize the skill."
fi

# Atomic move — either the new file is in place, or nothing changed
mv "$TMP_FILE" "$SKILL_DIR/SKILL.md"
trap - EXIT

echo "${GREEN}✓${RESET} /gesso-build skill installed"
echo "${DIM}  → $SKILL_DIR/SKILL.md${RESET}"
echo ""
echo "${BOLD}Next steps:${RESET}"
echo "  1. Make sure you have these MCP servers configured in Claude Code:"
echo "       ${DIM}claude mcp add --transport http --header \"Authorization: Bearer <KEY>\" Gesso https://api.gesso.so/mcp${RESET}"
echo "       ${DIM}claude mcp add railway-mcp-server -- npx -y @railway/mcp-server${RESET}"
echo "       ${DIM}claude mcp add github -- npx -y @modelcontextprotocol/server-github${RESET}"
echo ""
echo "  2. Open Claude Code and run:"
echo "       ${BOLD}/gesso-build${RESET}"
echo ""
