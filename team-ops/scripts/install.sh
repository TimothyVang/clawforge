#!/usr/bin/env bash
# team-ops install — Linux + macOS
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib.sh
source "$ROOT/scripts/lib.sh"
load_env

echo "==> team-ops install"
echo "    root: $TEAM_OPS_ROOT"

# --- prerequisites ---
need=()
command -v node >/dev/null || need+=("node (20+)")
command -v npm >/dev/null || need+=("npm")
command -v git >/dev/null || need+=("git")
command -v gh >/dev/null || need+=("gh (https://cli.github.com)")
if [ "${#need[@]}" -gt 0 ]; then
  echo "Install these first:" >&2
  printf '  - %s\n' "${need[@]}" >&2
  exit 1
fi

NODE_MAJOR="$(node -p 'process.versions.node.split(".")[0]')"
if [ "$NODE_MAJOR" -lt 20 ]; then
  echo "Node 20+ required (found $(node -v))" >&2
  exit 1
fi

# --- env file ---
if [ ! -f "$TEAM_OPS_ROOT/.env" ]; then
  cp "$TEAM_OPS_ROOT/.env.example" "$TEAM_OPS_ROOT/.env"
  echo "created .env from .env.example — edit secrets before production use"
fi

# --- Discord MCP deps ---
echo "==> npm install mcp/discord"
(cd "$TEAM_OPS_ROOT/mcp/discord" && npm install --no-fund --no-audit)

# --- Write resolved MCP snippets into .generated/ ---
GEN="$TEAM_OPS_ROOT/.generated"
mkdir -p "$GEN"
export TEAM_OPS_ROOT

render() {
  local src="$1" dest="$2"
  sed "s|TEAM_OPS_ROOT|${TEAM_OPS_ROOT}|g; s|\${TEAM_OPS_ROOT}|${TEAM_OPS_ROOT}|g" "$src" >"$dest"
  echo "    wrote $dest"
}

render "$TEAM_OPS_ROOT/config/mcp/claude.json" "$GEN/claude.mcp.json"
render "$TEAM_OPS_ROOT/config/mcp/grok.toml" "$GEN/grok.mcp.toml"
render "$TEAM_OPS_ROOT/config/mcp/opencode.jsonc" "$GEN/opencode.mcp.jsonc"
render "$TEAM_OPS_ROOT/config/mcp/codex.toml" "$GEN/codex.mcp.toml"
render "$TEAM_OPS_ROOT/config/mcp/cursor.json" "$GEN/cursor.mcp.json"

# Project-local Claude MCP (Claude Code reads .mcp.json in many setups)
cp "$GEN/claude.mcp.json" "$TEAM_OPS_ROOT/.mcp.json"
echo "    wrote $TEAM_OPS_ROOT/.mcp.json"

# Optional: merge hint files
cat >"$GEN/README.md" <<EOF
# Generated MCP configs

Absolute paths baked for: \`${TEAM_OPS_ROOT}\`

| File | Target harness |
|------|----------------|
| claude.mcp.json / ../.mcp.json | Claude Code |
| grok.mcp.toml | merge into ~/.grok/config.toml |
| opencode.mcp.jsonc | OpenCode MCP config |
| codex.mcp.toml | Codex CLI |
| cursor.mcp.json | Cursor |

Do not commit secrets. \`.env\` stays local.

Next: ./scripts/doctor.sh
EOF

# Ensure gitignore generated + env
grep -q '^\.generated' "$TEAM_OPS_ROOT/.gitignore" 2>/dev/null || echo '.generated/' >>"$TEAM_OPS_ROOT/.gitignore"

echo
echo "Install complete."
echo "  1. Edit .env (GITHUB_OWNER, tokens)"
echo "  2. ./scripts/doctor.sh"
echo "  3. Discord bot: discord/bot-setup.md"
echo "  4. Linear: scripts/bootstrap-linear.md"
echo "  5. GitHub: ./scripts/bootstrap-github.sh"
echo
echo "Discord invite: https://discord.gg/9FFySeV8B"
