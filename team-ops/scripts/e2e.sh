#!/usr/bin/env bash
# End-to-end automation for team-ops mesh (GitHub + Linear config + browser + scripts).
# Linear MCP is validated separately by agents; this script covers local + gh + CDP.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib.sh
source "$ROOT/scripts/lib.sh"
load_env

HACK="${HACKATHON_ROOT}"
OUT="${TEAM_OPS_E2E_DIR:-/tmp/team-ops-e2e}"
mkdir -p "$OUT"
: >"$OUT/log.txt"

pass=0 fail=0 warn=0
log() { echo "$*" | tee -a "$OUT/log.txt"; }
ok() { log "PASS  $1"; pass=$((pass + 1)); }
bad() { log "FAIL  $1"; fail=$((fail + 1)); }
wary() { log "WARN  $1"; warn=$((warn + 1)); }

log "=== team-ops E2E $(date -Iseconds) ==="

# 1. env
if [ -n "${GITHUB_OWNER:-}" ] && [ -n "${LINEAR_TEAM:-}" ] && [ -n "${HACKATHON_CDP_URL:-}" ]; then
  ok "env GITHUB_OWNER=$GITHUB_OWNER LINEAR_TEAM=$LINEAR_TEAM CDP=$HACKATHON_CDP_URL"
else
  bad "env incomplete"
fi

# 2. browser + CDP
if "$HACK/scripts/browser-start.sh" >>"$OUT/log.txt" 2>&1 \
  && curl -sf --max-time 3 "${HACKATHON_CDP_URL}/json/version" >"$OUT/cdp-version.json"; then
  ok "CDP ${HACKATHON_CDP_URL}"
else
  bad "CDP down"
fi

# 3. doctor + connect-all
if "$ROOT/scripts/doctor.sh" >"$OUT/doctor.txt" 2>&1; then ok "doctor.sh"; else bad "doctor.sh"; fi
if "$ROOT/scripts/connect-all.sh" >"$OUT/connect-all.txt" 2>&1; then ok "connect-all.sh"; else bad "connect-all.sh"; fi

# 4. GitHub
if USER="$(ghc api user -q .login 2>/dev/null)" && [ "$USER" = "TimothyVang" ]; then
  ok "gh auth as $USER"
else
  bad "gh auth"
fi
if ghc repo view "${GITHUB_OWNER}/team-ops" --json url -q .url 2>/dev/null | grep -q team-ops; then
  ok "repo ${GITHUB_OWNER}/team-ops"
else
  bad "repo view"
fi
COUNT="$(ghc issue list --repo "${GITHUB_OWNER}/team-ops" --json number -q 'length' 2>/dev/null || echo 0)"
if [ "$COUNT" -ge 3 ]; then ok "issues count=$COUNT"; else bad "issues count=$COUNT"; fi

MARK="e2e-$(date +%s)"
if ghc issue comment 1 --repo "${GITHUB_OWNER}/team-ops" \
  --body "E2E probe \`$MARK\` — GitHub OK · Linear team-ops · Discord invite · CDP 9230" \
  >"$OUT/gh-comment.txt" 2>&1; then
  ok "issue #1 comment $MARK"
else
  bad "issue comment"
fi

# 5. open surfaces
if "$HACK/scripts/open-sites.sh" \
  "https://github.com/${GITHUB_OWNER}/team-ops" \
  "https://linear.app/pugtest/project/team-ops-1cc18af37fc0" \
  "https://discord.com/app" \
  "https://discord.gg/9FFySeV8B" >>"$OUT/log.txt" 2>&1; then
  ok "open-sites GitHub+Linear+Discord"
else
  bad "open-sites"
fi

# 6. CDP tabs
curl -sf --max-time 5 "http://127.0.0.1:${RC_BROWSER_PORT}/json/list" -o "$OUT/tabs.json" || true
if python3 - <<PY
import json
from pathlib import Path
tabs=json.loads(Path("$OUT/tabs.json").read_text()) if Path("$OUT/tabs.json").exists() else []
urls=[t.get("url","") for t in tabs if t.get("type")=="page"]
need=["github.com/${GITHUB_OWNER}/team-ops","linear.app","discord"]
found={n: any(n in u for u in urls) for n in need}
Path("$OUT/tab-check.json").write_text(json.dumps({"urls":urls,"found":found}, indent=2))
print(found)
raise SystemExit(0 if all(found.values()) else 1)
PY
then
  ok "CDP tabs github+linear+discord"
else
  wary "CDP tabs incomplete (see $OUT/tab-check.json)"
fi

# 7. discord MCP
if node --check "$ROOT/mcp/discord/src/index.js" 2>/dev/null; then ok "discord MCP syntax"; else bad "discord MCP"; fi
if [ -z "${DISCORD_BOT_TOKEN:-}" ]; then wary "no DISCORD_BOT_TOKEN (browser fallback)"; else ok "bot token set"; fi

# 8. mcp.json
[ -f "$ROOT/.mcp.json" ] && ok ".mcp.json" || bad ".mcp.json"

# 9. connect-project fixture
if "$ROOT/scripts/connect-project.sh" e2e-fixture >>"$OUT/log.txt" 2>&1 \
  && { [ -f "${CLAWFORGE_ROOT:-}/../e2e-fixture/PROJECT.md" ] || [ -f "$HACK/projects/e2e-fixture/PROJECT.md" ]; }; then
  ok "connect-project e2e-fixture"
else
  bad "connect-project"
fi

# 10. linear config files
if [ -f "$ROOT/config/linear.env" ] && grep -q PUGtest "$ROOT/config/linear.env"; then
  ok "linear.env PUGtest"
else
  bad "linear.env"
fi

log ""
log "=== SUMMARY pass=$pass warn=$warn fail=$fail ==="
log "artifacts: $OUT"
printf '%s\n' "$pass" "$warn" "$fail" >"$OUT/counts.txt"
# Write machine-readable report
python3 - <<PY
import json, time
from pathlib import Path
out=Path("$OUT")
report={
  "at": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
  "pass": $pass,
  "warn": $warn,
  "fail": $fail,
  "github_owner": "${GITHUB_OWNER}",
  "linear_team": "${LINEAR_TEAM}",
  "linear_project_url": "${LINEAR_PROJECT_URL:-}",
  "cdp": "${HACKATHON_CDP_URL}",
  "discord_invite": "https://discord.gg/9FFySeV8B",
  "ok": $fail == 0,
}
out.joinpath("report.json").write_text(json.dumps(report, indent=2)+"\n")
print(json.dumps(report, indent=2))
PY

[ "$fail" -eq 0 ]
