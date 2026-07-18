# Clawforge

**NVIDIA Claw Agent Hackathon** project — forge agents, wire tools, ship with the crew.

| | |
|--|--|
| **Name** | Clawforge |
| **Folder** | `~/Desktop/hackathon/projects/clawforge/` |
| **Ops / PM** | `../team-ops/` |
| **Discord** | [HACKATHON TEAM](https://discord.gg/9FFySeV8B) |
| **Browser** | CDP `http://127.0.0.1:9230` (reuse tabs, no spam) |
| **GitHub owner** | TimothyVang (`gh` CLI) |

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

## Optional: push to GitHub

```bash
cd ~/Desktop/hackathon/projects/clawforge
git init -b main
git add -A && git commit -m "chore: bootstrap clawforge"
gh repo create TimothyVang/clawforge --private --source=. --remote=origin --push
```

## Related

- Team ops: `projects/team-ops/`
- Hackathon sandbox: `~/Desktop/hackathon`
