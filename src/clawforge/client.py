"""Swappable OpenAI-compatible model client.

Talks to any `/v1/chat/completions` endpoint — the vLLM server on the DGX Spark
(DeepSeek-V4-Flash or a small model), a NemoClaw-routed endpoint, or a mock. The
whole agent reasons through this one seam, so switching brains is a base_url change.

Nemotron-style models return their chain-of-thought in a separate
`reasoning_content` field; we surface it as the agent's decision trace.
"""
from __future__ import annotations

import time
from dataclasses import dataclass
from typing import Any

import requests

from .config import Config, CONFIG


class ModelError(RuntimeError):
    """Raised when the model endpoint is unreachable or returns an error.

    The heartbeat loop catches this to trigger failure recovery rather than crash.
    """


@dataclass
class ChatResult:
    content: str
    reasoning: str          # reasoning_content, if the model returns it
    usage: dict[str, Any]
    latency_s: float
    model: str


class ModelClient:
    def __init__(self, config: Config = CONFIG):
        self.cfg = config
        self._url = config.base_url.rstrip("/") + "/chat/completions"
        self._headers = {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {config.api_key or 'EMPTY'}",
            # Harmless for other servers; skips ngrok's browser-warning interstitial.
            "ngrok-skip-browser-warning": "true",
        }

    def chat(
        self,
        messages: list[dict[str, str]],
        max_tokens: int = 512,
        temperature: float = 0.2,
        response_format: dict | None = None,
    ) -> ChatResult:
        payload: dict[str, Any] = {
            "model": self.cfg.model,
            "messages": messages,
            "max_tokens": max_tokens,
            "temperature": temperature,
        }
        if response_format is not None:
            payload["response_format"] = response_format

        t0 = time.monotonic()
        try:
            resp = requests.post(
                self._url, json=payload, headers=self._headers,
                timeout=self.cfg.request_timeout,
            )
        except requests.RequestException as exc:
            raise ModelError(f"endpoint unreachable: {self._url} ({exc})") from exc

        dt = time.monotonic() - t0
        if resp.status_code != 200:
            raise ModelError(f"model HTTP {resp.status_code}: {resp.text[:300]}")

        try:
            data = resp.json()
            msg = data["choices"][0]["message"]
        except (ValueError, KeyError, IndexError) as exc:
            raise ModelError(f"bad model response: {resp.text[:300]}") from exc

        return ChatResult(
            content=(msg.get("content") or "").strip(),
            reasoning=(msg.get("reasoning_content") or "").strip(),
            usage=data.get("usage") or {},
            latency_s=round(dt, 2),
            model=data.get("model", self.cfg.model),
        )

    def warmup(self) -> bool:
        """Trigger the slow first-request JIT/autotune so real cycles are fast.

        Returns True if the endpoint answered, False otherwise (never raises).
        """
        try:
            self.chat(
                [{"role": "user", "content": "ok"}], max_tokens=4, temperature=0.0
            )
            return True
        except ModelError:
            return False

    def health(self) -> bool:
        try:
            r = requests.get(
                self.cfg.base_url.rstrip("/") + "/models",
                headers=self._headers, timeout=8,
            )
            return r.status_code == 200
        except requests.RequestException:
            return False
