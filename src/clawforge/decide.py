"""DECIDE — the reasoning brain. Turn sensed state into structured actions.

Calls the vLLM-served model to triage untriaged issues and write a standup.
Output is validated/coerced defensively (small models drift), and the model's
`reasoning_content` is kept as the observable decision trace judges want.
"""
from __future__ import annotations

import json
import re
from typing import Any

from .client import ModelClient
from .sense import label_names, watched_open_groups

TRIAGE_LABELS = ["triage/ready", "triage/blocked", "triage/question"]

# Trailing "/no_think" is the NVIDIA Nemotron-Nano reasoning-off toggle: it skips
# the <think> trace so we get the JSON directly (faster, cleaner). Models that
# don't recognize it ignore it, and _extract_json strips any trace anyway.
_SYSTEM = (
    "You are Clawforge, an autonomous software project manager. You look at open "
    "GitHub issues and triage each one. Respond with ONLY a single JSON object — "
    "no prose, no markdown fences.\n/no_think"
)

# Items are referenced by a 1-based [bracket] id, not the GitHub number: small
# models reliably echo the list position but often mangle a real issue number.
# decide() maps the id back to the true issue number + repo.
_SCHEMA = (
    '{"standup":"<=40 word team status","actions":[{"id":<bracket number>,'
    '"label":"triage/ready|triage/blocked|triage/question",'
    '"rationale":"<=20 words","ready":true}]}'
)


def _collect_untriaged(state: dict[str, Any]) -> list[dict[str, Any]]:
    out: list[dict[str, Any]] = []
    for repo, issues in watched_open_groups(state):
        for it in issues:
            if not any(l.startswith("triage/") for l in label_names(it)):
                out.append({**it, "_repo": repo})
    return out


def _build_messages(untriaged: list[dict[str, Any]]) -> list[dict[str, str]]:
    lines = []
    for idx, it in enumerate(untriaged, 1):
        body = (it.get("body") or "").strip().replace("\n", " ")[:240]
        lines.append(
            f'[{idx}] "{it["title"]}" (repo {it["_repo"]}) body="{body}"'
        )
    user = (
        "Open issues needing triage, each shown with a [bracket] id:\n"
        + ("\n".join(lines) or "(none)") + "\n\n"
        f"For EACH item pick exactly one label from {TRIAGE_LABELS}. "
        "'triage/ready' = clear and actionable now; 'triage/blocked' = waiting on "
        "something; 'triage/question' = needs clarification. Set 'ready':true only "
        "for triage/ready items a coding agent could implement unattended. "
        "In each action set 'id' to the item's [bracket] number exactly. "
        "Also write a one-line team standup.\n\n"
        f"Return JSON exactly like: {_SCHEMA}"
    )
    return [{"role": "system", "content": _SYSTEM}, {"role": "user", "content": user}]


def _extract_json(text: str) -> dict[str, Any] | None:
    # Drop any reasoning trace first — a <think>...</think> block can contain
    # brace-y prose that would poison the greedy JSON match below.
    t = re.sub(r"<think>.*?</think>", "", text, flags=re.S | re.I)
    t = re.sub(r"^```(?:json)?|```$", "", t.strip(), flags=re.M).strip()
    m = re.search(r"\{.*\}", t, re.S)
    if not m:
        return None
    try:
        return json.loads(m.group(0))
    except ValueError:
        return None


def decide(client: ModelClient, state: dict[str, Any]) -> dict[str, Any]:
    untriaged = _collect_untriaged(state)
    if not untriaged:
        return {
            "standup": f"{state['counts']['prs']} open PR(s); no untriaged issues.",
            "actions": [], "reasoning": "", "latency_s": 0.0, "untriaged": 0, "raw": "",
        }

    res = client.chat(_build_messages(untriaged), max_tokens=600, temperature=0.1)
    parsed = _extract_json(res.content) or {}

    # Map the model's 1-based [bracket] id back to the real issue. This is the
    # authoritative source for both number and repo — we never trust a raw issue
    # number from the model (small models echo the list position, not the id).
    # A legacy 'number' field is accepted as an id fallback for robustness.
    idx_to_issue = {i: (it["number"], it["_repo"]) for i, it in enumerate(untriaged, 1)}
    actions: list[dict[str, Any]] = []
    seen: set[int] = set()
    for a in parsed.get("actions") or []:
        try:
            idx = int(a.get("id", a.get("number")))
        except (TypeError, ValueError):
            continue
        if idx not in idx_to_issue or idx in seen:
            continue  # out-of-range / duplicate id — drop it
        seen.add(idx)
        label = str(a.get("label", "")).strip()
        if label not in TRIAGE_LABELS:
            continue
        num, repo = idx_to_issue[idx]
        actions.append({
            "number": num, "repo": repo, "label": label,
            "rationale": str(a.get("rationale", ""))[:120],
            "ready": bool(a.get("ready", False)) and label == "triage/ready",
        })

    return {
        "standup": str(parsed.get("standup", "")).strip()[:280],
        "actions": actions,
        "reasoning": res.reasoning,
        "latency_s": res.latency_s,
        "untriaged": len(untriaged),
        "raw": res.content,
    }
