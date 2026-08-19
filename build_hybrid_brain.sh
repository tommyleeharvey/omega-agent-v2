#!/data/data/com.termux/files/usr/bin/bash
set -x

REPO=~/omega-agent-v2
cd "$REPO"
TS=$(date +%Y%m%d-%H%M%S)
cp api/groq_client.py "api/groq_client.py.bak-$TS"

echo "=== 1) Create Gemini client (same pattern as claude_client.py) ==="
cat > api/gemini_client.py << 'GEMEOF'
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
GEMINI_MODEL = os.environ.get("GEMINI_MODEL", "gemini-2.5-flash")


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
GEMEOF
echo "gemini_client.py created."

echo ""
echo "=== 2) Wire Gemini into the hybrid chain + add cooldown cache to skip known-exhausted tiers ==="
python3 - << 'PYEOF'
path = "api/groq_client.py"
with open(path) as f:
    content = f.read()

# --- Add import for gemini_client ---
old_import = "from api import claude_client"
new_import = "from api import claude_client\nfrom api import gemini_client"
if old_import in content:
    content = content.replace(old_import, new_import)
    print("Import added.")
else:
    print("MANUAL: import line not found")
    raise SystemExit

# --- Add cooldown cache near the rate guard ---
old_guard = '''MAX_CALLS_PER_HOUR = int(os.environ.get("GROQ_MAX_CALLS_PER_HOUR", "120"))
_call_timestamps = []'''
new_guard = '''MAX_CALLS_PER_HOUR = int(os.environ.get("GROQ_MAX_CALLS_PER_HOUR", "120"))
_call_timestamps = []

# Per-model cooldown cache: model -> epoch time it becomes usable again.
# When a tier reports a daily-quota (TPD) exhaustion, there is no point
# retrying it on the next request for the next N minutes - it will just
# fail again and burn a wasted round trip before falling through. This
# cache lets the router skip straight past known-exhausted tiers instead,
# so every request only pays the cost of models actually worth trying.
_model_cooldowns = {}

def _is_on_cooldown(model):
    import time as _t
    resume = _model_cooldowns.get(model)
    return resume is not None and _t.time() < resume

def _set_cooldown(model, seconds):
    import time as _t
    _model_cooldowns[model] = _t.time() + seconds
    logger.info(f"{model} on cooldown for {seconds:.0f}s (daily quota exhausted)")'''
if old_guard in content:
    content = content.replace(old_guard, new_guard)
    print("Cooldown cache added.")
else:
    print("MANUAL: rate guard block not found")
    raise SystemExit

# --- Wire Gemini as second brain after Claude, before Groq tier stack ---
old_claude_block = '''    if _tier_start_index == 0 and os.environ.get("ANTHROPIC_API_KEY"):
        try:
            claude_result = claude_client.chat_completion(
                messages,
                max_tokens=max_tokens,
                tools=tools,
                return_message=True,
            )
            return claude_result if return_message else claude_result.get("content", "")
        except Exception as exc:
            logger.warning("Claude primary failed; falling through to Groq: %s", exc)'''
new_claude_block = '''    if _tier_start_index == 0 and os.environ.get("ANTHROPIC_API_KEY"):
        try:
            claude_result = claude_client.chat_completion(
                messages,
                max_tokens=max_tokens,
                tools=tools,
                return_message=True,
            )
            return claude_result if return_message else claude_result.get("content", "")
        except Exception as exc:
            logger.warning("Claude failed; trying Gemini: %s", exc)

    if _tier_start_index == 0 and os.environ.get("GEMINI_API_KEY"):
        try:
            gemini_result = gemini_client.chat_completion(
                messages,
                max_tokens=max_tokens,
                tools=tools,
                return_message=True,
            )
            return gemini_result if return_message else gemini_result.get("content", "")
        except Exception as exc:
            logger.warning("Gemini failed; falling through to Groq: %s", exc)'''
if old_claude_block in content:
    content = content.replace(old_claude_block, new_claude_block)
    print("Gemini wired in as second brain.")
else:
    print("MANUAL: claude block not found")
    raise SystemExit

# --- Skip cooldown models in the tier loop, and set cooldown on TPD 429s ---
old_tpm_check = '''        tpm_limit = MODEL_TPM_LIMITS.get(current_model)'''
new_tpm_check = '''        if _is_on_cooldown(current_model):
            last_error = f"{current_model}: skipped, on cooldown from earlier daily-quota exhaustion"
            continue

        tpm_limit = MODEL_TPM_LIMITS.get(current_model)'''
if old_tpm_check in content:
    content = content.replace(old_tpm_check, new_tpm_check)
    print("Cooldown skip added to tier loop.")
else:
    print("MANUAL: tpm_limit line not found")
    raise SystemExit

old_429 = '''        if resp.status_code == 429:
            wait_match = re.search(r"try again in ([\\d.]+)s", resp.text)
            wait_s = float(wait_match.group(1)) if wait_match else None
            is_daily_quota = "tokens per day" in resp.text or "TPD" in resp.text
            if is_daily_quota or idx < len(tier) - 1:'''
new_429 = '''        if resp.status_code == 429:
            wait_match = re.search(r"try again in ([\\d.]+)s", resp.text)
            wait_s = float(wait_match.group(1)) if wait_match else None
            is_daily_quota = "tokens per day" in resp.text or "TPD" in resp.text
            if is_daily_quota and wait_s:
                _set_cooldown(current_model, wait_s)
            if is_daily_quota or idx < len(tier) - 1:'''
if old_429 in content:
    content = content.replace(old_429, new_429)
    print("Cooldown-set-on-429 added.")
else:
    print("MANUAL: 429 block not found")
    raise SystemExit

with open(path, "w") as f:
    f.write(content)
print("All edits applied.")
PYEOF

echo ""
echo "=== Show diff ==="
git diff api/groq_client.py
git status --short api/gemini_client.py

echo ""
echo "=== Push ==="
git add api/gemini_client.py api/groq_client.py
git commit -m "feat: add Gemini as second-tier brain + cooldown cache to skip exhausted Groq models instead of retrying them every call"
git push origin main
