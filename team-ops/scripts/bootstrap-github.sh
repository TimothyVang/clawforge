#!/usr/bin/env bash
# Create GitHub meta repo + labels skeleton for team-ops
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib.sh
source "$ROOT/scripts/lib.sh"
load_env

if ! gh_bin >/dev/null 2>&1; then
  echo "gh CLI required: https://cli.github.com/" >&2
  exit 1
fi
if ! ghc auth status >/dev/null 2>&1; then
  echo "run: $(gh_bin) auth login" >&2
  exit 1
fi

OWNER="${GITHUB_OWNER:-}"
if [ -z "$OWNER" ]; then
  OWNER="$(ghc api user -q .login)"
  echo "GITHUB_OWNER unset — using $OWNER"
fi

VIS="${GITHUB_VISIBILITY:-private}"
REPO_NAME="${GITHUB_META_REPO:-team-ops}"
FULL="$OWNER/$REPO_NAME"

echo "==> bootstrap GitHub $FULL"

if ghc repo view "$FULL" >/dev/null 2>&1; then
  echo "repo exists: https://github.com/$FULL"
else
  ghc repo create "$FULL" --"$VIS" --description "team-ops: Linear + Discord + GitHub project management" --source "$ROOT" --remote origin --push 2>/dev/null \
    || ghc repo create "$FULL" --"$VIS" --description "team-ops meta"
  echo "created https://github.com/$FULL"
fi

# Labels (best-effort)
for spec in \
  "priority/urgent:b60205" \
  "priority/high:d93f0b" \
  "priority/medium:fbca04" \
  "priority/low:0e8a16" \
  "type/feature:1d76db" \
  "type/bug:d73a4a" \
  "type/chore:cfd3d7" \
  "team/core:5319e7"
do
  name="${spec%%:*}"
  color="${spec##*:}"
  ghc label create "$name" --repo "$FULL" --color "$color" --force >/dev/null 2>&1 || true
done
echo "labels ensured on $FULL"

# PR template
mkdir -p "$ROOT/.github"
if [ ! -f "$ROOT/.github/pull_request_template.md" ]; then
  cp "$ROOT/templates/pull_request_template.md" "$ROOT/.github/pull_request_template.md"
fi

echo
echo "Next:"
echo "  - Invite 5 collaborators: gh api -X PUT repos/$FULL/collaborators/USER -f permission=push"
echo "  - Set GITHUB_OWNER=$OWNER in .env"
echo "  - Connect apps: ./scripts/connect-project.sh <slug>"
