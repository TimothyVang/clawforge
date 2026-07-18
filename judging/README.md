# Clawforge local judge harness

## Canonical judge prompt

**[`PROMPT.md`](PROMPT.md)** — full evidence-first judging prompt (Find Evil / READY_FULL_E2E standard).

Use it by pasting into a fresh agent session or:

```bash
# From repo root (clawforge/)
# Open PROMPT.md as the system/judge prompt, then:
# "Judge this repository using judging/PROMPT.md. Operating mode: ASSESS_ONLY."
```

## Paths (from the prompt)

| Path | Purpose |
|------|---------|
| `judging/PROMPT.md` | Canonical judge instructions |
| `judging/scripts/` | Local harness scripts (to be added) |
| `judging/latest/` | Latest generated reports (gitignored) |
| `judging/runs/<timestamp>/` | Historical evidence (gitignored) |

## Non-negotiables (summary)

- Never pass without **direct evidence** (commands run, logs, traces).
- Video / Loom is **orientation only**, not proof.
- Trace findings to **code + execution**, not README confidence.
- Distinguish real hallucination controls from lucky runs.
- All judge-only state stays under `judging/`.
- Default mode: **ASSESS_ONLY** (no project code edits until REPAIR_MODE authorized).

## Event rubric

Hackathon scorecard (100 pts) lives in:

- [`../JUDGING.md`](../JUDGING.md)
- [`../docs/JUDGING.md`](../docs/JUDGING.md)

Run both: event track scoring **and** this evidence-first completeness audit.
