"""Cerebras adapter for Omega's hybrid model stack.

Dormant unless CEREBRAS_API_KEY is configured. Free tier: 1M tokens/day,
no card required. OpenAI-compatible request/response shape, so this is a
thin wrapper rather than a full conversion layer like claude/gemini clients.
Sits after Claude/Gemini, ahead of the Groq tier stack, as a genuine
parallel option rather than a last-resort fallback.
"""

import logging
import os

import requests

logger = logging.getLogger("CerebrasClient")
CEREBRAS_API_URL = "https://api.cerebras.ai/v1/chat/completions"
# gpt-oss-120b is Cerebras's current production-tier model as of Aug 2026.
# qwen-3-32b and llama-3.3-70b are scheduled for deprecation Feb 16 2026 -
# avoid those. Override via CEREBRAS_MODEL env var if this needs to change.
CEREBRAS_MODEL = os.environ.get("CEREBRAS_MODEL", "gpt-oss-120b")


def chat_completion(messages, max_tokens=2048, tools=None, return_message=False):
    key = os.environ.get("CEREBRAS_API_KEY")
    if not key:
        raise RuntimeError("CEREBRAS_API_KEY is not configured")
    payload = {
        "model": CEREBRAS_MODEL,
        "messages": messages,
        "max_completion_tokens": max_tokens,
    }
    if tools:
        payload["tools"] = tools
    response = requests.post(
        CEREBRAS_API_URL,
        headers={
            "Authorization": f"Bearer {key}",
            "Content-Type": "application/json",
        },
        json=payload,
        timeout=60,
    )
    if not response.ok:
        raise RuntimeError(f"Cerebras request failed ({response.status_code}): {response.text[:300]}")
    data = response.json()
    message = data["choices"][0]["message"]
    if return_message:
        return message
    return message.get("content", "")
