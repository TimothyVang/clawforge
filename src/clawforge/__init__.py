"""Clawforge — an autonomous AI project-manager agent (a "Claw Agent").

Heartbeat loop: senses GitHub issues/PRs + a Project board, reasons via a
vLLM-served model, then acts (triage, board moves, standups) and dispatches
coding sub-agents. State persists across restarts.
"""

__version__ = "0.1.0"
