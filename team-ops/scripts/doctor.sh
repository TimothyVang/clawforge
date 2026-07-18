#!/usr/bin/env bash
# Verify team-ops tooling + auth (never prints secret values)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib.sh
source "$ROOT/scripts/lib.sh"
load_env

ok=0
warn=0
fail=0

pass() { echo "  PASS  $1"; ok=$((ok + 1)); }
wary() { echo "  WARN  $1"; warn=$((warn + 1)); }
bad()  { echo "  FAIL  $1"; fail=$((fail + 1)); }

echo "==> team-ops doctor"
echo "    root: $TEAM_OPS_ROOT"

# Node
if command -v node >/dev/null; then
  pass "node $(node -v)"
else
  bad "node missing"
fi

# git
if command -v git >/dev/null; then pass "git $(git --version | awk '{print $3}')"; else bad "git missing"; fi

# gh (real binary — bypass shell aliases like gh='history|grep')
if bin="$(gh_bin 2>/dev/null)"; then
  if ghc auth status >/dev/null 2>&1; then
    user="$(ghc api user -q .login 2>/dev/null || echo '?')"
    pass "gh authenticated as $user ($bin)"
    if [ -n "${GITHUB_TOKEN:-}${GITHUB_PERSONAL_ACCESS_TOKEN:-}" ]; then
      pass "GITHUB_TOKEN exported from gh auth token (hidden)"
    fi
  else
    wary "gh installed but not logged in (run: gh auth login)"
  fi
else
  wary "gh not installed — GitHub MCP/scripts limited"
fi

# GITHUB_OWNER
if [ -n "${GITHUB_OWNER:-}" ]; then
  pass "GITHUB_OWNER=$GITHUB_OWNER"
else
  wary "GITHUB_OWNER unset"
fi

# Linear
if [ -n "${LINEAR_API_KEY:-}" ]; then
  pass "LINEAR_API_KEY set (value hidden)"
else
  wary "LINEAR_API_KEY unset — use Linear MCP OAuth in client"
fi
if [ -n "${LINEAR_TEAM:-}" ]; then pass "LINEAR_TEAM=$LINEAR_TEAM"; fi

# Discord
if [ -n "${DISCORD_BOT_TOKEN:-}" ]; then
  # identity check without printing token
  code="$(curl -sS -o /tmp/team-ops-discord-me.json -w '%{http_code}' \
    -H "Authorization: Bot ${DISCORD_BOT_TOKEN}" \
    https://discord.com/api/v10/users/@me 2>/dev/null || echo 000)"
  if [ "$code" = "200" ]; then
    bot="$(python3 -c 'import json;print(json.load(open("/tmp/team-ops-discord-me.json")).get("username","?"))' 2>/dev/null || echo bot)"
    pass "Discord bot OK ($bot)"
  else
    bad "Discord bot token rejected (HTTP $code)"
  fi
else
  wary "DISCORD_BOT_TOKEN unset — use browser fallback CDP 9230"
fi

if [ -n "${DISCORD_GUILD_ID:-}" ]; then pass "DISCORD_GUILD_ID set"; else wary "DISCORD_GUILD_ID unset"; fi

# Discord MCP package
if [ -d "$TEAM_OPS_ROOT/mcp/discord/node_modules/@modelcontextprotocol/sdk" ]; then
  pass "discord MCP dependencies installed"
else
  wary "run install.sh to npm install mcp/discord"
fi

# CDP fallback
if curl -sS --max-time 1 "${HACKATHON_CDP_URL:-http://127.0.0.1:9230}/json/version" >/dev/null 2>&1; then
  pass "hackathon browser CDP up (${HACKATHON_CDP_URL:-http://127.0.0.1:9230})"
else
  wary "CDP 9230 down — start: cd ~/Desktop/hackathon && ./scripts/browser-start.sh"
fi

# Generated MCP
if [ -f "$TEAM_OPS_ROOT/.mcp.json" ] || [ -f "$TEAM_OPS_ROOT/.generated/claude.mcp.json" ]; then
  pass "MCP snippets generated"
else
  wary "no generated MCP config — run install.sh"
fi

echo
echo "summary: pass=$ok warn=$warn fail=$fail"
if [ "$fail" -gt 0 ]; then exit 1; fi
exit 0
