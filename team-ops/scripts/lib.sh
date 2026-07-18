#!/usr/bin/env bash
# Shared helpers for team-ops scripts (CWD-independent).
# Layout: clawforge/team-ops/  (shipped inside https://github.com/TimothyVang/clawforge)
TEAM_OPS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export TEAM_OPS_ROOT

# Clawforge product root = parent of team-ops when nested.
if [ -d "$TEAM_OPS_ROOT/../judging" ] || [ -f "$TEAM_OPS_ROOT/../NAME.md" ]; then
  CLAWFORGE_ROOT="$(cd "$TEAM_OPS_ROOT/.." && pwd)"
else
  CLAWFORGE_ROOT="${CLAWFORGE_ROOT:-$TEAM_OPS_ROOT}"
fi
export CLAWFORGE_ROOT

# Walk up for optional hackathon sandbox (browser-start + cdp.env).
find_hackathon_root() {
  local d="$TEAM_OPS_ROOT" i
  for i in 1 2 3 4 5 6; do
    d="$(cd "$d/.." && pwd)" || return 1
    if [ -f "$d/config/cdp.env" ] || [ -x "$d/scripts/browser-start.sh" ]; then
      printf '%s' "$d"
      return 0
    fi
    [ "$d" = "/" ] && break
  done
  return 1
}
HACKATHON_ROOT="$(find_hackathon_root 2>/dev/null || true)"
export HACKATHON_ROOT

# Persistent isolated browser (CDP 9230). Never daily Brave 9223.
# shellcheck disable=SC1091
[ -n "${HACKATHON_ROOT:-}" ] && [ -f "$HACKATHON_ROOT/config/cdp.env" ] && source "$HACKATHON_ROOT/config/cdp.env"
# shellcheck disable=SC1091
[ -f "$TEAM_OPS_ROOT/config/browser.env" ] && source "$TEAM_OPS_ROOT/config/browser.env"
export HACKATHON_CDP_PORT="${HACKATHON_CDP_PORT:-9230}"
export HACKATHON_CDP_URL="${HACKATHON_CDP_URL:-http://127.0.0.1:${HACKATHON_CDP_PORT}}"
export RC_BROWSER_PORT="${RC_BROWSER_PORT:-$HACKATHON_CDP_PORT}"
export RC_CHROME_ISOLATE_PROJECT="${RC_CHROME_ISOLATE_PROJECT:-1}"
export AGENT_BROWSER_SESSION="${AGENT_BROWSER_SESSION:-hackathon}"

load_env() {
  local f="$TEAM_OPS_ROOT/.env"
  if [ -f "$f" ]; then
    set -a
    # shellcheck disable=SC1090
    source "$f"
    set +a
  fi
  # Non-secret GitHub identity (owner login)
  if [ -f "$TEAM_OPS_ROOT/config/github.env" ]; then
    set -a
    # shellcheck disable=SC1091
    source "$TEAM_OPS_ROOT/config/github.env"
    set +a
  fi
  # Non-secret Linear identity (team/project IDs)
  if [ -f "$TEAM_OPS_ROOT/config/linear.env" ]; then
    set -a
    # shellcheck disable=SC1091
    source "$TEAM_OPS_ROOT/config/linear.env"
    set +a
  fi
  # Non-secret Discord identity (guild/channels)
  if [ -f "$TEAM_OPS_ROOT/config/discord.env" ]; then
    set -a
    # shellcheck disable=SC1091
    source "$TEAM_OPS_ROOT/config/discord.env"
    set +a
  fi
  # Always re-assert browser pin after .env (project-owned values win if set)
  export HACKATHON_CDP_PORT="${HACKATHON_CDP_PORT:-9230}"
  export HACKATHON_CDP_URL="${HACKATHON_CDP_URL:-http://127.0.0.1:${HACKATHON_CDP_PORT}}"
  # Prefer live gh CLI token over stale GITHUB_TOKEN in .env
  auth_github_from_gh
}

# Resolve real GitHub CLI even if shell aliases `gh` to something else
# (this machine had: alias gh='history|grep').
gh_bin() {
  if [ -n "${GH_BIN:-}" ] && [ -x "$GH_BIN" ]; then
    printf '%s' "$GH_BIN"
    return 0
  fi
  local c
  for c in \
    "$HOME/.local/bin/gh" \
    /usr/bin/gh \
    /bin/gh \
    /opt/homebrew/bin/gh \
    /usr/local/bin/gh
  do
    if [ -x "$c" ]; then
      GH_BIN="$c"
      export GH_BIN
      printf '%s' "$c"
      return 0
    fi
  done
  # Last resort: unaliased command lookup
  if type -P gh >/dev/null 2>&1; then
    type -P gh
    return 0
  fi
  return 1
}

ghc() {
  local bin
  bin="$(gh_bin)" || {
    echo "GitHub CLI (gh) not found" >&2
    return 127
  }
  "$bin" "$@"
}

# Export GITHUB_TOKEN + GITHUB_OWNER from authenticated gh session.
# Does not print the token.
auth_github_from_gh() {
  local bin token owner
  bin="$(gh_bin 2>/dev/null)" || return 0
  if ! "$bin" auth status >/dev/null 2>&1; then
    return 0
  fi
  token="$("$bin" auth token 2>/dev/null || true)"
  if [ -n "$token" ]; then
    export GITHUB_TOKEN="$token"
    export GITHUB_PERSONAL_ACCESS_TOKEN="$token"
    export GH_TOKEN="$token"
  fi
  owner="$("$bin" api user -q .login 2>/dev/null || true)"
  if [ -n "$owner" ]; then
    # Only fill owner if unset or still placeholder
    if [ -z "${GITHUB_OWNER:-}" ] || [ "$GITHUB_OWNER" = "YOUR_OWNER" ]; then
      export GITHUB_OWNER="$owner"
    fi
  fi
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "missing: $1" >&2
    return 1
  }
}

abs_root() {
  printf '%s' "$TEAM_OPS_ROOT"
}

ensure_project_browser() {
  local start=""
  if [ -n "${HACKATHON_ROOT:-}" ] && [ -x "$HACKATHON_ROOT/scripts/browser-start.sh" ]; then
    start="$HACKATHON_ROOT/scripts/browser-start.sh"
  fi
  if [ -n "$start" ]; then
    "$start" >/dev/null 2>&1 || "$start" || true
  fi
}
