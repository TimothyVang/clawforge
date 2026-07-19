"""Unit tests for the model client's HTTP 429 back-off/retry behavior."""
from __future__ import annotations

import os
from unittest.mock import patch

os.environ["CLAWFORGE_MODEL_RETRY_BASE"] = "0.01"
os.environ["CLAWFORGE_MODEL_MAX_RETRIES"] = "3"

import pytest

from clawforge import client as client_mod
from clawforge.client import ModelClient, ModelError, _retry_after_seconds
from clawforge.config import Config


class _Resp:
    def __init__(self, status, body="", headers=None, js=None):
        self.status_code = status
        self.text = body
        self.headers = headers or {}
        self._js = js

    def json(self):
        return self._js


_GOOD = _Resp(200, js={
    "choices": [{"message": {"content": "hi", "reasoning_content": ""}}],
    "usage": {}, "model": "m",
})


def _post_seq(seq):
    it = iter(seq)
    calls = {"n": 0}

    def post(url, **kw):
        calls["n"] += 1
        return next(it)

    return post, calls


class TestRetryAfterParse:
    def test_delta_seconds(self):
        assert _retry_after_seconds("2") == 2.0

    def test_float_seconds(self):
        assert _retry_after_seconds("0.5") == 0.5

    def test_http_date_falls_back_to_none(self):
        assert _retry_after_seconds("Wed, 21 Oct 2026 07:28:00 GMT") is None

    def test_negative_rejected(self):
        assert _retry_after_seconds("-3") is None

    def test_missing_header(self):
        assert _retry_after_seconds(None) is None


class TestChatRateLimit:
    def test_429_twice_then_success(self):
        post, calls = _post_seq([_Resp(429, "rl"), _Resp(429, "rl"), _GOOD])
        with patch.object(client_mod.requests, "post", post):
            res = ModelClient(Config()).chat([{"role": "user", "content": "x"}])
        assert res.content == "hi"
        assert calls["n"] == 3

    def test_retry_after_header_honored(self):
        post, calls = _post_seq([_Resp(429, "rl", headers={"Retry-After": "0.01"}), _GOOD])
        with patch.object(client_mod.requests, "post", post):
            res = ModelClient(Config()).chat([{"role": "user", "content": "x"}])
        assert res.content == "hi"
        assert calls["n"] == 2

    def test_exhaustion_raises_model_error(self):
        post, calls = _post_seq([_Resp(429, "rl")] * 10)
        with patch.object(client_mod.requests, "post", post):
            with pytest.raises(ModelError, match="rate limited"):
                ModelClient(Config()).chat([{"role": "user", "content": "x"}])
        assert calls["n"] == 4  # initial + max_retries

    def test_non_429_error_fails_fast(self):
        post, calls = _post_seq([_Resp(500, "boom")] + [_GOOD] * 5)
        with patch.object(client_mod.requests, "post", post):
            with pytest.raises(ModelError, match="HTTP 500"):
                ModelClient(Config()).chat([{"role": "user", "content": "x"}])
        assert calls["n"] == 1
