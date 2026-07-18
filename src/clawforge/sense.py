"""SENSE — read the current world state the PM agent reasons about.

Open issues (+ labels/body) and PRs in the watched repo, plus open issues in the
work repo (the dispatch target). GitHub is the tracker of record; auth via `gh`.
"""
from __future__ import annotations

from typing import Any

from .config import Config, CONFIG
from .gh import gh


def _issues(repo: str, limit: int = 30, state: str = "open") -> list[dict[str, Any]]:
    try:
        return gh(
            "issue", "list", "--repo", repo, "--state", state,
            "--json", "number,title,labels,body,url", "--limit", str(limit),
            json_out=True,
        ) or []
    except RuntimeError:
        return []


def _prs(repo: str, limit: int = 30) -> list[dict[str, Any]]:
    try:
        return gh(
            "pr", "list", "--repo", repo, "--state", "open",
            "--json", "number,title,url,isDraft", "--limit", str(limit),
            json_out=True,
        ) or []
    except RuntimeError:
        return []


def read_state(config: Config = CONFIG) -> dict[str, Any]:
    repo = config.watched_repo
    work = config.work_repo_full
    state = {
        "repo": repo,
        "work_repo": work,
        "issues": _issues(repo),
        "work_issues": _issues(work),
        "closed_issues": _issues(repo, limit=20, state="closed"),
        "closed_work_issues": _issues(work, limit=20, state="closed"),
        "prs": _prs(repo),
    }
    state["counts"] = {
        "issues": len(state["issues"]),
        "work_issues": len(state["work_issues"]),
        "prs": len(state["prs"]),
    }
    return state


def label_names(issue: dict[str, Any]) -> list[str]:
    return [lbl.get("name", "") for lbl in issue.get("labels", [])]
