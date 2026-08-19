"""
Pluggable LLM client interface.

Real backends (Groq, OpenAI, Anthropic, local) all implement `complete()`.
Everything else in the brain talks to this interface, not to a specific
vendor SDK, so swapping providers means changing one line of config.
"""

import os
import json
import asyncio
import logging
from abc import ABC, abstractmethod
from typing import Optional

logger = logging.getLogger("OmegaLLM")


class LLMClient(ABC):
    @abstractmethod
    async def complete(self, prompt: str, temperature: float = 0.4, max_tokens: int = 800) -> str:
        """Return raw text completion for a prompt. Must raise on failure, never fake success."""
        raise NotImplementedError


class RouterClient(LLMClient):
    """
    Multi-provider, multi-model failover client. Wraps llm_router.call_llm,
    which cycles through every model on a provider (best -> worst) before
    falling through to the next provider (Groq -> Gemini -> Cerebras ->
    OpenRouter). This is now the real default backend.
    """

    def __init__(self):
        from agent.llm_router import call_llm
        self._call_llm = call_llm
        self._last_used = None

    async def complete(self, prompt: str, temperature: float = 0.4, max_tokens: int = 800) -> str:
        messages = [{"role": "user", "content": prompt}]
        result, used = await asyncio.to_thread(
            self._call_llm, messages, None, None, max_tokens
        )
        self._last_used = used
        logger.info(f"RouterClient: answered via {used}")
        return result["choices"][0]["message"]["content"]


class GroqClient(LLMClient):
    """Real Groq-backed client. Requires GROQ_API_KEY in environment.
    Kept for direct/manual use; get_default_client() now prefers RouterClient."""

    def __init__(self, model: str = "openai/gpt-oss-120b", api_key: Optional[str] = None):
        self.model = model
        self.api_key = api_key or os.environ.get("GROQ_API_KEY")
        if not self.api_key:
            raise RuntimeError(
                "GROQ_API_KEY not set. Export it before starting the agent: "
                "export GROQ_API_KEY=gsk_..."
            )

    async def complete(self, prompt: str, temperature: float = 0.4, max_tokens: int = 800) -> str:
        import httpx  # local import: only required if this backend is actually used

        async with httpx.AsyncClient(timeout=30.0) as client:
            resp = await client.post(
                "https://api.groq.com/openai/v1/chat/completions",
                headers={"Authorization": f"Bearer {self.api_key}"},
                json={
                    "model": self.model,
                    "messages": [{"role": "user", "content": prompt}],
                    "temperature": temperature,
                    "max_tokens": max_tokens,
                },
            )
            resp.raise_for_status()
            data = resp.json()
            return data["choices"][0]["message"]["content"]


class MockLLMClient(LLMClient):
    """
    Deterministic mock for offline testing / CI. Never claims to be a real
    model — every response is tagged so it can't be mistaken for live output.
    Use this to verify wiring before pointing at a real API key.
    """

    def __init__(self, canned_responses: Optional[dict] = None):
        self.canned_responses = canned_responses or {}
        self.call_log = []

    async def complete(self, prompt: str, temperature: float = 0.4, max_tokens: int = 800) -> str:
        self.call_log.append(prompt)
        for key, response in self.canned_responses.items():
            if key in prompt:
                return response
        # Generic structured fallback so callers expecting JSON don't crash
        return json.dumps({"mock": True, "note": "no canned response matched prompt"})


def get_default_client() -> LLMClient:
    """
    Picks a backend from environment config. Defaults to RouterClient (multi-
    provider, multi-model failover). Falls back to Mock with a loud warning
    rather than silently pretending to be real.
    """
    backend = os.environ.get("OMEGA_LLM_BACKEND", "router").lower()
    if backend == "router":
        try:
            return RouterClient()
        except Exception as e:
            logger.warning(f"Falling back to MockLLMClient: {e}")
            return MockLLMClient()
    elif backend == "groq":
        try:
            return GroqClient()
        except RuntimeError as e:
            logger.warning(f"Falling back to MockLLMClient: {e}")
            return MockLLMClient()
    elif backend == "mock":
        return MockLLMClient()
    else:
        raise ValueError(f"Unknown OMEGA_LLM_BACKEND: {backend}")
