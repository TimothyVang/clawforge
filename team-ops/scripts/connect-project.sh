#!/usr/bin/env bash
# Link a project slug across GitHub + local PROJECT.md + team.yaml stub
# Linear/Discord channel creation is documented for agents (API may need tokens)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib.sh
source "$ROOT/scripts/lib.sh"
load_env

SLUG="${1:-}"
if [ -z "$SLUG" ]; then
  echo "usage: $0 <project-slug>" >&2
  exit 1
fi

SAFE="$(printf '%s' "$SLUG" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9._-' '-' | sed 's/^-*//;s/-*$//')"
OWNER="${GITHUB_OWNER:-}"
if [ -z "$OWNER" ] && gh_bin >/dev/null 2>&1; then
  OWNER="$(ghc api user -q .login 2>/dev/null || true)"
fi
OWNER="${OWNER:-YOUR_OWNER}"

# Prefer sibling product under same parent as clawforge (or clawforge/apps)
if [ -n "${CLAWFORGE_ROOT:-}" ] && [ -d "$(dirname "$CLAWFORGE_ROOT")" ]; then
  PROJECTS_PARENT="$(cd "$(dirname "$CLAWFORGE_ROOT")" && pwd)"
else
  PROJECTS_PARENT="$(cd "$ROOT/.." && pwd)"
fi
DEST="${CONNECT_DEST:-$PROJECTS_PARENT/$SAFE}"

echo "==> connect-project $SAFE"
echo "    dest: $DEST"

mkdir -p "$DEST"

if [ ! -d "$DEST/.git" ]; then
  git -C "$DEST" init -q
fi

# README if missing
if [ ! -f "$DEST/README.md" ]; then
  sed "s/{{SLUG}}/$SAFE/g; s/{{OWNER}}/$OWNER/g" "$ROOT/templates/repo-README.md" >"$DEST/README.md"
fi

# PROJECT.md linkage
cat >"$DEST/PROJECT.md" <<EOF
# $SAFE — project links

| Surface | Link / id |
|---------|-----------|
| GitHub | https://github.com/$OWNER/$SAFE |
| Linear | (create project "$SAFE" on team ${LINEAR_TEAM:-Core}) |
| Discord | #proj-$SAFE (or #dev) — invite https://discord.gg/9FFySeV8B |

## Conventions

- Issues: Linear \`TEAM-n\`
- Branches: \`team-n-short-slug\`
- PR titles: \`[TEAM-n] …\`

## Agent

Use team-ops prompts from:

\`$ROOT/config/prompts/\`

MCP configs: \`$ROOT/.generated/\` (after install.sh)
EOF

# Optional GitHub repo create
if gh_bin >/dev/null 2>&1 && ghc auth status >/dev/null 2>&1; then
  FULL="$OWNER/$SAFE"
  if ! ghc repo view "$FULL" >/dev/null 2>&1; then
    echo "creating GitHub repo $FULL …"
    (cd "$DEST" && ghc repo create "$FULL" --"${GITHUB_VISIBILITY:-private}" --source=. --remote=origin --push) \
      || (cd "$DEST" && ghc repo create "$FULL" --"${GITHUB_VISIBILITY:-private}" && git -C "$DEST" remote add origin "https://github.com/$FULL.git" || true)
  else
    echo "GitHub repo exists: https://github.com/$FULL"
    git -C "$DEST" remote get-url origin >/dev/null 2>&1 \
      || git -C "$DEST" remote add origin "https://github.com/$FULL.git"
  fi
else
  echo "skip GitHub create (gh not auth'd) — set remote manually"
fi

# Append to team.yaml projects if not present
if ! grep -q "slug: $SAFE" "$ROOT/config/team.yaml" 2>/dev/null; then
  cat >>"$ROOT/config/team.yaml" <<EOF

# added by connect-project $(date -Iseconds 2>/dev/null || date)
# - slug: $SAFE
#   github: $OWNER/$SAFE
#   linear_project: "$SAFE"
#   discord_channel: ""
EOF
  echo "appended stub to config/team.yaml (uncomment and fill discord_channel)"
fi

echo
echo "Done."
echo "  code:    $DEST"
echo "  github:  https://github.com/$OWNER/$SAFE"
echo "  linear:  create project via agent + Linear MCP (prompt new-project.md)"
echo "  discord: create #proj-$SAFE or map channel id in team.yaml"
echo
echo "Agent paste:"
echo "  Connect repo $SAFE using config/prompts/connect-repo.md and Linear MCP."
