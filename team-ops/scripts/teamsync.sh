#!/usr/bin/env bash
# TeamSync — one-shot mesh refresh for the hackathon crew.
# Usage:
#   ./scripts/teamsync.sh
#   ./scripts/teamsync.sh --check    # doctor + report only (no browser open)
#   ./scripts/teamsync.sh --quiet
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib.sh
source "$ROOT/scripts/lib.sh"
load_env

CHECK_ONLY=0
QUIET=0
for arg in "$@"; do
  case "$arg" in
    --check|-c) CHECK_ONLY=1 ;;
    --quiet|-q) QUIET=1 ;;
    -h|--help)
      sed -n '2,8p' "$0" | sed 's/^# //;s/^#//'
      exit 0
      ;;
  esac
done

log() { [ "$QUIET" -eq 1 ] || echo "$*"; }
HACK="${HACKATHON_ROOT:-}"
OPEN_SITES=""
if [ -n "$HACK" ] && [ -x "$HACK/scripts/open-sites.sh" ]; then
  OPEN_SITES="$HACK/scripts/open-sites.sh"
fi
GEN="${ROOT}/.generated"
mkdir -p "$GEN"
TS="$(date -u +%Y%m%dT%H%M%SZ 2>/dev/null || date +%Y%m%d%H%M%S)"
REPORT="${GEN}/teamsync-${TS}.md"
LATEST="${GEN}/teamsync-latest.md"

OWNER="${GITHUB_OWNER:-TimothyVang}"
CLAW_REPO="${OWNER}/clawforge"
OPS_REPO="${OWNER}/team-ops"
DISCORD_URL="${DISCORD_OPEN_URL:-https://discord.com/channels/${DISCORD_GUILD_ID:-1527816191148818522}/${DISCORD_CHANNEL_GENERAL:-1527816191588958221}}"
INVITE="${DISCORD_INVITE:-https://discord.gg/9FFySeV8B}"
CDP_URL="${HACKATHON_CDP_URL:-http://127.0.0.1:9230}"

status="OK"
crit_fail=0
warns=0
cmds=()

note_cmd() { cmds+=("$*"); }
mark_warn() { warns=$((warns + 1)); [ "$status" = "FAIL" ] || status="DEGRADED"; }
mark_fail() { crit_fail=1; status="FAIL"; }

log "=========================================="
log " TeamSync  ${TS}"
log "=========================================="
log " root: ${ROOT}"
log " product: clawforge  ops: team-ops"
log

# --- 1. Browser ---
browser_state="DOWN"
if [ "$CHECK_ONLY" -eq 0 ]; then
  log "==> browser CDP"
  note_cmd "ensure_project_browser"
  ensure_project_browser || true
  if curl -sf --max-time 2 "${CDP_URL}/json/version" >/dev/null 2>&1; then
    browser_state="UP"
    log "  CDP ${CDP_URL} UP"
  else
    browser_state="DOWN"
    log "  CDP ${CDP_URL} DOWN"
    mark_fail
  fi

  if [ -x "$OPEN_SITES" ] && [ "$browser_state" = "UP" ]; then
    urls=(
      "$DISCORD_URL"
      "https://github.com/${CLAW_REPO}"
      "https://github.com/${OPS_REPO}"
    )
    # Optional Linear only if wired
    if [ -n "${LINEAR_PROJECT_URL:-}" ]; then
      urls+=("${LINEAR_PROJECT_URL}")
    fi
    note_cmd "open-sites.sh (reuse-first) ${urls[*]}"
    log "  open-sites (reuse tabs)…"
    if ! "$OPEN_SITES" "${urls[@]}" >"${GEN}/teamsync-open-sites.log" 2>&1; then
      log "  open-sites WARN (see ${GEN}/teamsync-open-sites.log)"
      mark_warn
    else
      # show reuse summary if present
      tail -n 3 "${GEN}/teamsync-open-sites.log" 2>/dev/null | sed 's/^/  /' || true
    fi
  elif [ "$CHECK_ONLY" -eq 0 ]; then
    log "  skip open-sites (missing or CDP down)"
  fi
else
  log "==> browser check-only"
  if curl -sf --max-time 2 "${CDP_URL}/json/version" >/dev/null 2>&1; then
    browser_state="UP"
    log "  CDP UP"
  else
    browser_state="DOWN"
    log "  CDP DOWN"
    mark_fail
  fi
fi

# --- 2. Doctor ---
log
log "==> doctor"
note_cmd "./scripts/doctor.sh"
doctor_out="${GEN}/teamsync-doctor.log"
if "$ROOT/scripts/doctor.sh" >"$doctor_out" 2>&1; then
  log "  doctor: exit 0"
else
  log "  doctor: non-zero (warnings may be OK)"
  mark_warn
fi
[ "$QUIET" -eq 1 ] || sed 's/^/  /' "$doctor_out" | tail -n 20

# --- 3. GitHub collect ---
log
log "==> GitHub"
gh_user=""
gh_ok=0
if gh_bin >/dev/null 2>&1 && ghc auth status >/dev/null 2>&1; then
  gh_user="$(ghc api user -q .login 2>/dev/null || true)"
  log "  auth: ${gh_user:-?}"
  note_cmd "gh api user"
  if [ -n "$gh_user" ]; then gh_ok=1; else mark_fail; fi
else
  log "  auth: FAIL (gh not logged in)"
  mark_fail
fi

claw_ok=0 ops_ok=0
claw_url="" ops_url=""
claw_issues=0 ops_issues=0
if [ "$gh_ok" -eq 1 ]; then
  if ghc repo view "$CLAW_REPO" --json url -q .url >/dev/null 2>&1; then
    claw_ok=1
    claw_url="$(ghc repo view "$CLAW_REPO" --json url -q .url 2>/dev/null || true)"
    claw_issues="$(ghc issue list --repo "$CLAW_REPO" --json number -q 'length' 2>/dev/null || echo 0)"
    log "  clawforge: ${claw_url}  issues=${claw_issues}"
  else
    log "  clawforge: MISSING ${CLAW_REPO}"
    mark_warn
  fi
  if ghc repo view "$OPS_REPO" --json url -q .url >/dev/null 2>&1; then
    ops_ok=1
    ops_url="$(ghc repo view "$OPS_REPO" --json url -q .url 2>/dev/null || true)"
    ops_issues="$(ghc issue list --repo "$OPS_REPO" --json number -q 'length' 2>/dev/null || echo 0)"
    log "  team-ops:  ${ops_url}  issues=${ops_issues}"
  else
    log "  team-ops:  MISSING ${OPS_REPO}"
    mark_warn
  fi
fi

# --- 4. Discord ---
log
log "==> Discord"
log "  invite:  ${INVITE}"
log "  open:    ${DISCORD_URL}"
log "  guild:   ${DISCORD_GUILD_ID:-unset}"
log "  general: ${DISCORD_CHANNEL_GENERAL:-${DISCORD_CHANNEL_DEV:-unset}}"
log "  standup: ${DISCORD_CHANNEL_STANDUP:-unset}"
if [ -z "${DISCORD_GUILD_ID:-}" ]; then
  mark_warn
fi
if [ -n "${DISCORD_BOT_TOKEN:-}" ]; then
  code="$(curl -sS -o /tmp/teamsync-discord-me.json -w '%{http_code}' \
    -H "Authorization: Bot ${DISCORD_BOT_TOKEN}" \
    https://discord.com/api/v10/users/@me 2>/dev/null || echo 000)"
  if [ "$code" = "200" ]; then
    bot="$(python3 -c 'import json;print(json.load(open("/tmp/teamsync-discord-me.json")).get("username","?"))' 2>/dev/null || echo bot)"
    log "  bot:     OK (${bot})"
  else
    log "  bot:     token present but HTTP ${code}"
    mark_warn
  fi
else
  log "  bot:     unset (browser fallback OK)"
  mark_warn
fi

# --- 5. Linear ---
log
log "==> Linear"
if [ -n "${LINEAR_PROJECT_URL:-}" ] && [ -n "${LINEAR_TEAM:-}" ]; then
  log "  wired:   team=${LINEAR_TEAM} project=${LINEAR_PROJECT:-?} url=${LINEAR_PROJECT_URL}"
  linear_state="wired"
else
  log "  skipped: not configured (team-ops Linear was canceled; product work in clawforge)"
  linear_state="skipped"
fi

# --- 6. Report ---
{
  echo "# TeamSync ${TS}"
  echo
  echo "## Status: **${status}**"
  echo
  echo "| Surface | State |"
  echo "|---------|--------|"
  echo "| Browser CDP | ${browser_state} · \`${CDP_URL}\` |"
  echo "| GitHub auth | ${gh_user:-FAIL} |"
  echo "| clawforge | $([ "$claw_ok" -eq 1 ] && echo "OK · ${claw_url} · issues ${claw_issues}" || echo "MISSING") |"
  echo "| team-ops | $([ "$ops_ok" -eq 1 ] && echo "OK · ${ops_url} · issues ${ops_issues}" || echo "MISSING") |"
  echo "| Discord | guild \`${DISCORD_GUILD_ID:-unset}\` · ${INVITE} |"
  echo "| Discord bot | $([ -n "${DISCORD_BOT_TOKEN:-}" ] && echo set || echo unset) |"
  echo "| Linear | ${linear_state} |"
  echo
  echo "## Product"
  echo
  echo "- **Clawforge:** \`${CLAWFORGE_ROOT:-?}\` · https://github.com/${CLAW_REPO}"
  echo "- **Team ops:** \`${ROOT}\` (inside clawforge) · https://github.com/${OPS_REPO}"
  echo "- **Judging prompt:** \`judging/PROMPT.md\` (repo root)"
  echo
  echo "## Discord channels"
  echo
  echo "| Role | ID |"
  echo "|------|-----|"
  echo "| guild | \`${DISCORD_GUILD_ID:-}\` |"
  echo "| general | \`${DISCORD_CHANNEL_GENERAL:-${DISCORD_CHANNEL_DEV:-}}\` |"
  echo "| standup | \`${DISCORD_CHANNEL_STANDUP:-}\` |"
  echo "| notes/linear | \`${DISCORD_CHANNEL_LINEAR:-${DISCORD_CHANNEL_NOTES:-}}\` |"
  echo
  echo "## Commands run"
  echo
  for c in "${cmds[@]}"; do
    echo "- \`${c}\`"
  done
  echo
  echo "## Next actions"
  echo
  if [ "$crit_fail" -eq 1 ]; then
    echo "1. Fix critical: \`gh auth login\` and/or \`~/Desktop/hackathon/scripts/browser-start.sh\`"
  else
    echo "1. Product work: repo root (parent of team-ops/) or \`cd ${CLAWFORGE_ROOT:-..}\`"
    echo "2. Optional: set \`DISCORD_BOT_TOKEN\` for agent posts (else browser CDP)"
    echo "3. Optional: re-wire Linear in \`config/linear.env\` if needed"
    echo "4. Agent follow-up: paste \`config/prompts/teamsync.md\`"
  fi
  echo
  echo "## Agent one-liner"
  echo
  echo '```'
  echo "Run TeamSync follow-up using config/prompts/teamsync.md. Read .generated/teamsync-latest.md and CONNECTIONS.md. Do not open new browser tabs if hosts already open."
  echo '```'
} >"$REPORT"

cp "$REPORT" "$LATEST"

log
log "=========================================="
log " TeamSync ${status}  (warns=${warns} critical=${crit_fail})"
log " report: ${LATEST}"
log " prompt: ${ROOT}/config/prompts/teamsync.md"
log "=========================================="
log
log "Agent follow-up:"
log "  Run TeamSync using config/prompts/teamsync.md"
log "  Read .generated/teamsync-latest.md — reuse browser tabs."
log

[ "$crit_fail" -eq 0 ]
