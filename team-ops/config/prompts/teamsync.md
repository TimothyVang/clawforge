# Prompt — TeamSync (one-shot)

You are running **TeamSync** for the AITX × NVIDIA Claw Agent Hackathon crew.

## Context

| Surface | Truth |
|---------|--------|
| Product | **Clawforge** · `projects/clawforge/` · https://github.com/TimothyVang/clawforge |
| Ops mesh | **team-ops** · this repo · https://github.com/TimothyVang/team-ops |
| Discord | **HACKATHON TEAM** · https://discord.gg/9FFySeV8B |
| Browser | Isolated CDP **http://127.0.0.1:9230** — **reuse tabs, never spam new ones** |
| Linear | Optional; may be unwired/canceled — skip if `config/linear.env` empty |

## Prerequisites

The human should have run (or you run):

```bash
cd <team-ops-root>
./scripts/teamsync.sh
```

Then read:

1. `.generated/teamsync-latest.md` (machine report)
2. `CONNECTIONS.md`
3. `config/discord.env` / `config/github.env`

## Your job (follow-up after the script)

1. **Confirm** TeamSync report status is OK or DEGRADED (not FAIL). If FAIL, fix critical blockers only (`gh auth`, browser CDP), re-run `./scripts/teamsync.sh`.
2. **GitHub:** via `gh` or GitHub MCP — confirm `TimothyVang/clawforge` and `TimothyVang/team-ops` exist; note open issues relevant to the crew.
3. **Discord:**
   - Guild/channels from env are the source of truth.
   - If `DISCORD_BOT_TOKEN` is set, optionally post a short message to **#general**:
     `TeamSync OK — Clawforge + team-ops mesh verified. CDP 9230.`
   - If no bot token: do **not** invent success; state browser is open on the server (script already activated tab).
4. **Linear:** only if wired. Otherwise state “Linear skipped.”
5. **Clawforge judging:** point to `projects/clawforge/judging/PROMPT.md` + `JUDGING.md` for product readiness — TeamSync is mesh sync, not product E2E.
6. **Tab rule:** never call open-sites/new tab if github.com / discord.com / linear.app already has a page open.

## Output format

```markdown
# TeamSync agent report

## Verdict
OK | DEGRADED | FAIL

## Mesh
| Surface | Status | Evidence |
|---------|--------|----------|
| Browser | | |
| GitHub clawforge | | |
| GitHub team-ops | | |
| Discord | | |
| Linear | | |

## Blockers
1. …

## Next action
One sentence only.
```

## Do not

- Recreate canceled Linear projects unless the user asks
- Open stacks of new browser tabs
- Claim Discord bot posts without a token
- Mark product “READY” from TeamSync alone
