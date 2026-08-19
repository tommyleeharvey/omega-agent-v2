"""Google Gemini adapter for Omega's hybrid model stack.

Dormant unless GEMINI_API_KEY is configured. Free tier: Gemini 2.5 Flash,
1,500 requests/day, no card required, 1M token context. Sits as the second
brain in the fallback chain, behind Claude and ahead of the Groq tier stack.
"""

import json
import logging
import os
from typing import Any

import requests

logger = logging.getLogger("GeminiClient")
GEMINI_API_URL = "https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent"
# gemini-2.5-flash was retired for new API accounts (404: "no longer
# available to new users"). gemini-3.6-flash is Google's current stable
# Flash model as of Aug 2026 - use GEMINI_MODEL env var to override without
# a redeploy if Google moves the goalposts again.
GEMINI_MODEL = os.environ.get("GEMINI_MODEL", "gemini-3.6-flash")


def _text_from_content(content: Any) -> str:
    if isinstance(content, str):
        return content
    if not isinstance(content, list):
        return str(content or "")
    return "\n".join(
        str(block.get("text", ""))
        for block in content
        if isinstance(block, dict) and block.get("type") == "text"
    ).strip()


def _convert_messages(messages):
    system_parts = []
    contents = []
    for message in messages:
        role = message.get("role", "user")
        if role == "system":
            system_parts.append(_text_from_content(message.get("content", "")))
            continue
        if role == "tool":
            contents.append({
                "role": "user",
                "parts": [{
                    "functionResponse": {
                        "name": message.get("name", "tool_result"),
                        "response": {"result": str(message.get("content", ""))},
                    }
                }],
            })
            continue
        gemini_role = "model" if role == "assistant" else "user"
        text = _text_from_content(message.get("content", ""))
        parts = [{"text": text}] if text else []
        if role == "assistant" and message.get("tool_calls"):
            for call in message["tool_calls"]:
                function = call.get("function", {})
                try:
                    args = json.loads(function.get("arguments", "{}"))
                except (TypeError, json.JSONDecodeError):
                    args = {}
                parts.append({
                    "functionCall": {"name": function.get("name", ""), "args": args}
                })
        if parts:
            contents.append({"role": gemini_role, "parts": parts})
    return system_parts, contents


def _convert_tools(tools):
    if not tools:
        return None
    declarations = []
    for tool in tools:
        function = tool.get("function", tool)
        declarations.append({
            "name": function.get("name", ""),
            "description": function.get("description", ""),
            "parameters": function.get("parameters", {"type": "object", "properties": {}}),
        })
    return [{"functionDeclarations": declarations}]


def _normalize_response(payload):
    candidates = payload.get("candidates", [])
    if not candidates:
        raise RuntimeError(f"Gemini returned no candidates: {payload}")
    parts = candidates[0].get("content", {}).get("parts", [])
    text_parts = []
    tool_calls = []
    for i, part in enumerate(parts):
        if "text" in part:
            text_parts.append(part["text"])
        elif "functionCall" in part:
            fc = part["functionCall"]
            tool_calls.append({
                "id": f"gemini_call_{i}",
                "type": "function",
                "function": {
                    "name": fc.get("name", ""),
                    "arguments": json.dumps(fc.get("args", {}), separators=(",", ":")),
                },
            })
    message = {"role": "assistant", "content": "\n".join(text_parts).strip()}
    if tool_calls:
        message["tool_calls"] = tool_calls
    return message


def chat_completion(messages, max_tokens=2048, tools=None, return_message=False):
    key = os.environ.get("GEMINI_API_KEY")
    if not key:
        raise RuntimeError("GEMINI_API_KEY is not configured")
    system_parts, contents = _convert_messages(messages)
    payload = {
        "contents": contents,
        "generationConfig": {"maxOutputTokens": max_tokens},
    }
    if system_parts:
        payload["systemInstruction"] = {"parts": [{"text": "\n\n".join(p for p in system_parts if p)}]}
    converted_tools = _convert_tools(tools)
    if converted_tools:
        payload["tools"] = converted_tools

    url = GEMINI_API_URL.format(model=os.environ.get("GEMINI_MODEL", GEMINI_MODEL))
    response = requests.post(url, params={"key": key}, json=payload, timeout=60)
    if not response.ok:
        raise RuntimeError(f"Gemini request failed ({response.status_code}): {response.text[:300]}")
    normalized = _normalize_response(response.json())
    if return_message:
        return normalized
    return normalized.get("content", "")
