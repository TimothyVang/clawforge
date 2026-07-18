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
from .sense import label_names

TRIAGE_LABELS = ["triage/ready", "triage/blocked", "triage/question"]

_SYSTEM = (
    "You are Clawforge, an autonomous software project manager. You look at open "
    "GitHub issues and triage each one. Respond with ONLY a single JSON object — "
    "no prose, no markdown fences."
)

_SCHEMA = (
    '{"standup":"<=40 word team status","actions":[{"number":<int>,'
    '"repo":"owner/repo","label":"triage/ready|triage/blocked|triage/question",'
    '"rationale":"<=20 words","ready":true}]}'
)


def _collect_untriaged(state: dict[str, Any]) -> list[dict[str, Any]]:
    out: list[dict[str, Any]] = []
    for key, repo in (("issues", state["repo"]), ("work_issues", state["work_repo"])):
        for it in state.get(key, []):
            if not any(l.startswith("triage/") for l in label_names(it)):
                out.append({**it, "_repo": repo})
    return out


def _build_messages(untriaged: list[dict[str, Any]]) -> list[dict[str, str]]:
    lines = []
    for it in untriaged:
        body = (it.get("body") or "").strip().replace("\n", " ")[:240]
        lines.append(
            f'- #{it["number"]} [{it["_repo"]}] "{it["title"]}" body="{body}"'
        )
    user = (
        "Open issues needing triage:\n" + ("\n".join(lines) or "(none)") + "\n\n"
        f"For EACH issue pick exactly one label from {TRIAGE_LABELS}. "
        "'triage/ready' = clear and actionable now; 'triage/blocked' = waiting on "
        "something; 'triage/question' = needs clarification. Set 'ready':true only "
        "for triage/ready issues a coding agent could implement unattended. "
        "Also write a one-line team standup.\n\n"
        f"Return JSON exactly like: {_SCHEMA}"
    )
    return [{"role": "system", "content": _SYSTEM}, {"role": "user", "content": user}]


def _extract_json(text: str) -> dict[str, Any] | None:
    t = re.sub(r"^```(?:json)?|```$", "", text.strip(), flags=re.M).strip()
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

    valid_repos = {state["repo"], state["work_repo"]}
    actions: list[dict[str, Any]] = []
    for a in parsed.get("actions") or []:
        try:
            num = int(a["number"])
        except (KeyError, TypeError, ValueError):
            continue
        label = str(a.get("label", "")).strip()
        if label not in TRIAGE_LABELS:
            continue
        repo = str(a.get("repo", "")).strip()
        if repo not in valid_repos:
            repo = state["repo"]
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
