#!/usr/bin/env bash
# Verify and print the full GitHub + Linear + Discord + browser mesh.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib.sh
source "$ROOT/scripts/lib.sh"
load_env
ensure_project_browser

echo "=========================================="
echo " team-ops CONNECTED MESH"
echo "=========================================="
echo
echo "GitHub"
echo "  owner:  ${GITHUB_OWNER:-?}"
if gh_bin >/dev/null 2>&1 && ghc auth status >/dev/null 2>&1; then
  echo "  auth:   $(ghc api user -q .login) via gh CLI"
  echo "  repo:   https://github.com/${GITHUB_OWNER:-TimothyVang}/team-ops"
  ghc repo view "${GITHUB_OWNER:-TimothyVang}/team-ops" --json url,homepageUrl,description \
    -q '"  home:   " + (.homepageUrl // "") + "\n  desc:   " + (.description // "")' 2>/dev/null || true
  echo "  issues:"
  ghc issue list --repo "${GITHUB_OWNER:-TimothyVang}/team-ops" --limit 10 2>/dev/null | sed 's/^/    /' || true
else
  echo "  auth:   NOT logged in"
fi

echo
echo "Linear"
echo "  workspace: ${LINEAR_WORKSPACE:-pugtest}"
echo "  team:      ${LINEAR_TEAM:-PUGtest} (key ${LINEAR_TEAM_KEY:-PUG})"
echo "  project:   ${LINEAR_PROJECT:-team-ops}"
echo "  url:       ${LINEAR_PROJECT_URL:-https://linear.app/pugtest/project/team-ops-1cc18af37fc0}"
echo "  (issues managed via Linear MCP / web UI)"

echo
echo "Discord"
echo "  invite:  https://discord.gg/9FFySeV8B"
if [ -n "${DISCORD_BOT_TOKEN:-}" ]; then
  code="$(curl -sS -o /tmp/team-ops-d.json -w '%{http_code}' \
    -H "Authorization: Bot ${DISCORD_BOT_TOKEN}" \
    https://discord.com/api/v10/users/@me 2>/dev/null || echo 000)"
  if [ "$code" = "200" ]; then
    bot="$(python3 -c 'import json;print(json.load(open("/tmp/team-ops-d.json")).get("username","?"))' 2>/dev/null || echo bot)"
    echo "  bot:     OK ($bot)"
  else
    echo "  bot:     token present but HTTP $code"
  fi
else
  echo "  bot:     not configured — use browser CDP ${HACKATHON_CDP_URL}"
fi
echo "  guild:   ${DISCORD_GUILD_ID:-unset}"

echo
echo "Browser (project-persistent)"
echo "  CDP:     ${HACKATHON_CDP_URL}"
echo "  session: ${AGENT_BROWSER_SESSION:-hackathon}"
if curl -sS --max-time 1 "${HACKATHON_CDP_URL}/json/version" >/dev/null 2>&1; then
  echo "  state:   UP"
else
  echo "  state:   DOWN — run: $HACKATHON_ROOT/scripts/browser-start.sh"
fi

echo
echo "Local hub"
echo "  $ROOT/CONNECTIONS.md"
echo "  $ROOT/config/linear.env"
echo "  $ROOT/config/github.env"
echo "  $ROOT/config/browser.env"
echo
echo "=========================================="
echo " Mesh ready. Optional: Discord bot token, invite 4 teammates."
echo "=========================================="

# Refresh generated MCP paths
if [ -x "$ROOT/scripts/install.sh" ]; then
  # quiet re-render without full npm if node_modules exists
  GEN="$ROOT/.generated"
  mkdir -p "$GEN"
  for pair in \
    "config/mcp/claude.json:.generated/claude.mcp.json" \
    "config/mcp/grok.toml:.generated/grok.mcp.toml" \
    "config/mcp/opencode.jsonc:.generated/opencode.mcp.jsonc" \
    "config/mcp/codex.toml:.generated/codex.mcp.toml"
  do
    src="$ROOT/${pair%%:*}"
    dest="$ROOT/${pair##*:}"
    [ -f "$src" ] || continue
    sed "s|TEAM_OPS_ROOT|${ROOT}|g; s|\${TEAM_OPS_ROOT}|${ROOT}|g" "$src" >"$dest"
  done
  cp "$GEN/claude.mcp.json" "$ROOT/.mcp.json" 2>/dev/null || true
  echo "MCP snippets refreshed under .generated/ and .mcp.json"
fi
