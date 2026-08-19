"""OpenRouter adapter for Omega's hybrid model stack.

Dormant unless OPENROUTER_API_KEY is configured. Uses OpenRouter's
"openrouter/free" auto-router instead of a hardcoded :free model ID -
OpenRouter's free model roster rotates weekly (models get delisted with
no notice), so pinning a specific ID is a guaranteed future outage.
The auto-router picks among currently-available free models and filters
for tool-calling support automatically. Free tier: 20 req/min, 50 req/day
(no card required). Not a primary tier - sits after Claude/Gemini/Cerebras,
ahead of the Groq stack, as a fallback option rather than first choice.
"""

import logging
import os

import requests

logger = logging.getLogger("OpenRouterClient")
OPENROUTER_API_URL = "https://openrouter.ai/api/v1/chat/completions"
OPENROUTER_MODEL = os.environ.get("OPENROUTER_MODEL", "openrouter/free")


def chat_completion(messages, max_tokens=2048, tools=None, return_message=False):
    key = os.environ.get("OPENROUTER_API_KEY")
    if not key:
        raise RuntimeError("OPENROUTER_API_KEY is not configured")
    payload = {
        "model": OPENROUTER_MODEL,
        "messages": messages,
        "max_tokens": max_tokens,
    }
    if tools:
        payload["tools"] = tools
    response = requests.post(
        OPENROUTER_API_URL,
        headers={
            "Authorization": f"Bearer {key}",
            "Content-Type": "application/json",
            "HTTP-Referer": "https://tommyleeharvey.github.io/omega-agent-v2/",
            "X-Title": "Omega Agent v2",
        },
        json=payload,
        timeout=60,
    )
    if not response.ok:
        raise RuntimeError(f"OpenRouter request failed ({response.status_code}): {response.text[:300]}")
    data = response.json()
    message = data["choices"][0]["message"]
    if return_message:
        return message
    return message.get("content", "")
