# Clawforge Hub — one place to find code, PRs, projects, and access

Single front door for the crew. Everything is on GitHub; access is public
fork-and-PR, so anyone can jump in with their own GitHub login — no invites,
no OAuth app to manage.

## Repos (all code)

| Repo | Visibility | What |
|------|-----------|------|
| [TimothyVang/clawforge](https://github.com/TimothyVang/clawforge) | Public | Product + `team-ops/` mesh + judging |
| [TimothyVang/e2e-fixture](https://github.com/TimothyVang/e2e-fixture) | Private | Team fixture app (`TEAM-n` convention) |

> New apps in the sandbox live under `hackathon/projects/<name>/`. Add each one
> to this table and to the Project board (below) when it gets a repo.

## Project board (all PRs + issues, one view)

<!-- BOARD_URL: paste the GitHub Project (v2) URL here once created -->
**Board:** _not created yet_ — needs the `project` scope on the `gh` token:

```bash
gh auth refresh -s project -s read:project        # one-time, interactive
gh project create --owner TimothyVang --title "Clawforge"
# then enable the board's built-in "Auto-add" workflow per repo so every new
# issue/PR lands here automatically (Project → ⋯ → Workflows → Auto-add).
```

Until then, PRs and issues are tracked per-repo natively:
- clawforge: <https://github.com/TimothyVang/clawforge/pulls> · [issues](https://github.com/TimothyVang/clawforge/issues)

## How to contribute (public fork/PR flow)

```bash
# 1. Fork on GitHub (button), or:
gh repo fork TimothyVang/clawforge --clone
cd clawforge
# 2. Branch, commit, push to your fork
git checkout -b my-change
git commit -am "feat: my change"
git push -u origin my-change
# 3. Open a PR back to clawforge
gh pr create --repo TimothyVang/clawforge --fill
```

No write access needed — fork, PR, and a maintainer merges.

## Access / auth

| Surface | How people get in |
|---------|-------------------|
| Code (read/clone/fork) | Public — any GitHub account, nothing to grant |
| Open a PR | Fork + PR (above) — GitHub handles auth |
| Chat | Discord invite: <https://discord.gg/9FFySeV8B> |
| Merge / maintainer | Repo owner (`TimothyVang`) |

## Status + tooling

- Live mesh status: [`team-ops/CONNECTIONS.md`](team-ops/CONNECTIONS.md)
- One-shot sync + health: `./team-ops/scripts/teamsync.sh` (`--check` to skip browser)
- Health only: `./team-ops/scripts/doctor.sh`
