# Clawforge

**NVIDIA Claw Agent Hackathon** project — forge agents, wire tools, ship with the crew.

| | |
|--|--|
| **Name** | Clawforge |
| **Folder** | `~/Desktop/hackathon/projects/clawforge/` |
| **Ops / PM** | [`team-ops/`](team-ops/) (in this repo) |
| **Discord** | [HACKATHON TEAM](https://discord.gg/9FFySeV8B) |
| **Browser** | CDP `http://127.0.0.1:9230` (reuse tabs, no spam) |
| **GitHub** | https://github.com/TimothyVang/clawforge (public) |
| **Hub** | [`HUB.md`](HUB.md) — code, PRs, project board, and how to get access |

## Judging

Hackathon rubric, scorecard, submission checklist, and evidence-first audit:

- **[JUDGING.md](JUDGING.md)** — quick view + how to run the judge prompt  
- **[docs/JUDGING.md](docs/JUDGING.md)** — full event judge prep (100-pt breakdown)  
- **[judging/PROMPT.md](judging/PROMPT.md)** — canonical evidence-first judge prompt  
- **[judging/README.md](judging/README.md)** — local harness layout

## Layout

```
clawforge/
  src/       # agent / product code
  docs/      # design, prompts, JUDGING.md
  scripts/   # project tooling
  JUDGING.md # quick judging card
```

## Related

- Team ops: [`team-ops/`](team-ops/)
- Hackathon sandbox: `~/Desktop/hackathon`

## Team mesh sync

```bash
./team-ops/scripts/teamsync.sh
```

Prompt for agents: `./team-ops/config/prompts/teamsync.md`

