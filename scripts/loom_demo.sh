#!/usr/bin/env bash
# loom_demo.sh — drives the live Loom demo in order, pausing between beats.
# Usage: start Loom recording, then run:  ./scripts/loom_demo.sh
# Press Enter to advance each beat. Narration cues in docs/LOOM_SHOTLIST.md.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

beat() {
  echo
  echo "==================================================================="
  echo "BEAT $1 — $2"
  echo "==================================================================="
  read -r -p "[Enter to run] "
}

beat 1 "The agent is ALIVE and unattended (systemd, not a prompt)"
systemctl --user status clawforge.service --no-pager | head -8
tail -3 .generated/clawforge/clawforge.log

beat 2 "The brain: DeepSeek-V4-Flash on vLLM 0.24 on the DGX Spark (keyed)"
grep "start model=" .generated/clawforge/clawforge.log | tail -1
BASE=$(cd src && python3 -c "from clawforge.config import Config; print(Config().base_url)")
KEY=$(cd src && python3 -c "from clawforge.config import Config; print(Config().api_key)")
curl -s -H "Authorization: Bearer $KEY" -H "ngrok-skip-browser-warning: true" \
  "$BASE/models" | python3 -m json.tool | head -8
echo "(note owned_by + the vllm system_fingerprint on any chat reply; unauth = 401)"

beat 3 "FRESH INPUT: file a real issue — no human will touch it again"
gh issue create --repo davidbramante/tickytalky \
  --title "Add a docs/FAQ.md answering the top 5 creator questions" \
  --body "Write a single file docs/FAQ.md: what TickyTalky is, what the blind win rate means, what the Playbook is, how cold-vs-warm proves learning, and how demo data stays deterministic. One new file, no code changes. (Filed live during the Loom demo.)"

beat 4 "WATCH THE HEARTBEAT: triage happens with zero human input (~3 min cycle)"
echo "Waiting for the next cycle to triage it..."
N0=$(wc -l < .generated/clawforge/cycle-history.jsonl)
until [ "$(wc -l < .generated/clawforge/cycle-history.jsonl)" -gt "$N0" ]; do sleep 5; done
tail -2 .generated/clawforge/clawforge.log
python3 -c "
import json
r=[json.loads(l) for l in open('.generated/clawforge/cycle-history.jsonl')][-1]
print('cycle', r['cycle'], '| latency', r.get('latency_s'), 's')
print('standup:', r.get('standup'))
print('actions:', [(a['number'], a['label']) for a in r.get('actions', [])])"

beat 5 "FULL DELEGATION: the agent's own PRs on the team repo (never auto-merged)"
gh pr list --repo davidbramante/tickytalky --state open | head -8

beat 6 "PERSISTENT + AUDITABLE: ledger and append-only reasoning history"
python3 -c "
import json
d=json.load(open('.generated/clawforge/ledger.json'))
print('lifetime cycles:', d['cycles'], '| idempotency records:', len(d['acted']))"
tail -1 .generated/clawforge/cycle-history.jsonl | head -c 300; echo " ..."

beat 7 "SELF-HEALING, PROVEN: 4 fault scenarios x3 + negative control (~90s)"
bash judging/scripts/self_heal_e2e.sh
python3 -c "
import json
r=json.load(open('judging/latest/self_heal_result.json'))
print('overall:', r['overall_verdict'], '| canary:', r['canary'])
for s in r['scenarios']: print(f\"  {s['id']}: {s['verdict']} ({s['name']})\")"

echo
echo "=== DEMO COMPLETE — board: https://github.com/users/TimothyVang/projects/1 ==="
