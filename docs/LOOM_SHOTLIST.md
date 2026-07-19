# Loom shot list (2–5 min) — run `./scripts/loom_demo.sh` and narrate

Recording setup: Loom → full-screen terminal, font large. The script pauses at
each beat; press Enter when you finish the line of narration.

| Beat | On screen | Say (roughly) |
|------|-----------|----------------|
| 1 | systemd status + live log | "Clawforge is an autonomous PM agent. It's running as a service right now — heartbeat, not prompts. Nobody is typing to it." |
| 2 | endpoint /models + fingerprint | "Its brain is DeepSeek-V4-Flash — 159 billion params — served by vLLM 0.24 on an NVIDIA DGX Spark, behind a keyed endpoint. We swapped brains live mid-event with one env var." |
| 3 | `gh issue create` runs | "Fresh input, live: I'm filing a real issue on our team's repo. This is the last human action you'll see." |
| 4 | waiting → triage output | "On its next heartbeat the agent senses it, reasons with DeepSeek, and triages it — label, rationale, standup. Watch the latency: that's real model reasoning." |
| 5 | PR list | "Ready issues get dispatched to a coding sub-agent that opens real PRs — here are the ones it authored. It never auto-merges; humans review." |
| 6 | ledger + history record | "Everything is idempotent and auditable: a ledger that survives restarts, and an append-only reasoning history." |
| 7 | self_heal_e2e.sh runs live | "And we don't just claim resilience — this harness injects four real faults: endpoint death, a 429 storm, kill -9, corrupted state. Three iterations each plus a negative control, honestly labeled as controlled fault injection. All green." |
| — | board URL | "Issues to triage to PRs to Done, on a public board, unattended. That's a Claw agent." |

Honesty notes for narration (keep credibility with evidence-first judges):
- Say "controlled fault injection" for beat 7 — do NOT call it organic failure.
- Beat 4's cycle may be idle if nothing is untriaged — that's why beat 3 files
  the issue first. If timing is unlucky, the script just waits for the cycle.
- Do not claim NemoClaw runs live (it's architected, not wired — see SUBMISSION).
