# Clawforge Hub — one place to find code, PRs, projects, and access

Single front door for the crew. Everything is on GitHub; access is public
fork-and-PR, so anyone can jump in with their own GitHub login — no invites,
no OAuth app to manage.

## Repos (all code)

| Repo | Visibility | What |
|------|-----------|------|
| [TimothyVang/clawforge](https://github.com/TimothyVang/clawforge) | Public | Product + `team-ops/` mesh + judging |
| [9prodhi/Namoclaw-hackathon](https://github.com/9prodhi/Namoclaw-hackathon) | Public | Teammate entry (NemoClaw + ace-research) — clawforge's **watched repo** |
| [davidbramante/tickytalky](https://github.com/davidbramante/tickytalky) | Public | TikTok AI strategist — clawforge's **work repo** (autonomous PRs land here) |
| [TimothyVang/e2e-fixture](https://github.com/TimothyVang/e2e-fixture) | Private | Team fixture app (`TEAM-n` convention) — repo currently empty |

> New apps in the sandbox live under `hackathon/projects/<name>/`. Add each one
> to this table and to the Project board (below) when it gets a repo.

## Project board (all PRs + issues, one view)

**Board:** <https://github.com/users/TimothyVang/projects/1> (public) — the single
place PRs and issues are tracked. Linked repo: `clawforge`.

**Track another repo:** link it, then it can feed the board:

```bash
gh project link 1 --owner TimothyVang --repo <repo>
```

**Auto-add future issues/PRs (one-time UI toggle):** open the board →
**⋯ → Workflows → "Auto-add to project"** → enable and pick the linked repo(s).
This is the only step the API can't do headlessly; after it's on, every new
issue/PR lands on the board automatically.

**Add an existing issue/PR by hand:**

```bash
gh project item-add 1 --owner TimothyVang --url <issue-or-pr-url>
```

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
