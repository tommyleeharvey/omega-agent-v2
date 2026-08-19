#!/data/data/com.termux/files/usr/bin/bash
set -x

echo "=== Check if a Cerebras key already exists anywhere ==="
grep -oE "CEREBRAS_API_KEY=.*" ~/.omega/nexus/.env 2>/dev/null
grep -oE "CEREBRAS_API_KEY=.*" ~/.omega/.env 2>/dev/null
grep -rl "csk-" ~/.omega/ ~/omega-agent-v2/ 2>/dev/null | grep -v node_modules

REPO=~/omega-agent-v2
cd "$REPO"
TS=$(date +%Y%m%d-%H%M%S)
cp api/groq_client.py "api/groq_client.py.bak-$TS"

echo "=== 1) Create OpenRouter client (OpenAI-compatible, uses auto-router to dodge free-model rotation) ==="
cat > api/openrouter_client.py << 'OREOF'
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
OREOF
echo "openrouter_client.py created."

echo ""
echo "=== 2) Wire OpenRouter in after Cerebras, before Groq tier stack ==="
python3 - << 'PYEOF'
path = "api/groq_client.py"
with open(path) as f:
    content = f.read()

has_cerebras = "from api import cerebras_client" in content
import_target = "from api import cerebras_client" if has_cerebras else "from api import gemini_client"
new_import = import_target + "\nfrom api import openrouter_client"
if import_target in content:
    content = content.replace(import_target, new_import)
    print(f"Import added after {import_target}.")
else:
    print("MANUAL: expected import line not found")
    raise SystemExit

if has_cerebras:
    old_block = '''    if _tier_start_index == 0 and os.environ.get("CEREBRAS_API_KEY"):
        try:
            cerebras_result = cerebras_client.chat_completion(
                messages,
                max_tokens=max_tokens,
                tools=tools,
                return_message=True,
            )
            return cerebras_result if return_message else cerebras_result.get("content", "")
        except Exception as exc:
            logger.warning("Cerebras failed; falling through to Groq: %s", exc)'''
    new_block = '''    if _tier_start_index == 0 and os.environ.get("CEREBRAS_API_KEY"):
        try:
            cerebras_result = cerebras_client.chat_completion(
                messages,
                max_tokens=max_tokens,
                tools=tools,
                return_message=True,
            )
            return cerebras_result if return_message else cerebras_result.get("content", "")
        except Exception as exc:
            logger.warning("Cerebras failed; trying OpenRouter: %s", exc)

    if _tier_start_index == 0 and os.environ.get("OPENROUTER_API_KEY"):
        try:
            or_result = openrouter_client.chat_completion(
                messages,
                max_tokens=max_tokens,
                tools=tools,
                return_message=True,
            )
            return or_result if return_message else or_result.get("content", "")
        except Exception as exc:
            logger.warning("OpenRouter failed; falling through to Groq: %s", exc)'''
else:
    old_block = '''    if _tier_start_index == 0 and os.environ.get("GEMINI_API_KEY"):
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
    new_block = '''    if _tier_start_index == 0 and os.environ.get("GEMINI_API_KEY"):
        try:
            gemini_result = gemini_client.chat_completion(
                messages,
                max_tokens=max_tokens,
                tools=tools,
                return_message=True,
            )
            return gemini_result if return_message else gemini_result.get("content", "")
        except Exception as exc:
            logger.warning("Gemini failed; trying OpenRouter: %s", exc)

    if _tier_start_index == 0 and os.environ.get("OPENROUTER_API_KEY"):
        try:
            or_result = openrouter_client.chat_completion(
                messages,
                max_tokens=max_tokens,
                tools=tools,
                return_message=True,
            )
            return or_result if return_message else or_result.get("content", "")
        except Exception as exc:
            logger.warning("OpenRouter failed; falling through to Groq: %s", exc)'''

count = content.count(old_block)
print(f"Exact match occurrences: {count}")
if count == 1:
    content = content.replace(old_block, new_block)
    with open(path, "w") as f:
        f.write(content)
    print("OpenRouter wired in.")
else:
    print("MANUAL: target block not found, aborting.")
    raise SystemExit
PYEOF

echo ""
echo "=== 3) Set the existing OpenRouter key on Render ==="
curl -s -X PUT \
  -H "Authorization: Bearer rnd_vv9FVHwsb9nQr5Giy527Gq5LTAwa" \
  -H "Content-Type: application/json" \
  "https://api.render.com/v1/services/srv-da20pelg1s2s73de3n70/env-vars/OPENROUTER_API_KEY" \
  -d '{"value": "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"}'

echo ""
echo "=== 4) Show diff, commit, push ==="
git diff api/groq_client.py
git status --short api/openrouter_client.py
git add api/openrouter_client.py api/groq_client.py
git commit -m "feat: add OpenRouter (auto-router free tier) as fallback brain before Groq stack"
git push origin main

echo ""
echo "=== 5) Redeploy, wait, confirm ==="
curl -s -X POST \
  -H "Authorization: Bearer rnd_vv9FVHwsb9nQr5Giy527Gq5LTAwa" \
  "https://api.render.com/v1/services/srv-da20pelg1s2s73de3n70/deploys" \
  | python3 -m json.tool

sleep 60
curl -s -H "Authorization: Bearer rnd_vv9FVHwsb9nQr5Giy527Gq5LTAwa" \
  "https://api.render.com/v1/services/srv-da20pelg1s2s73de3n70/deploys?limit=2" \
  | python3 -c "
import sys, json
d = json.load(sys.stdin)
for dep in d:
    dep = dep.get('deploy', dep)
    print(dep.get('commit', {}).get('id', '')[:8], '-', dep.get('status'))
"
curl -s https://omega-agent-backend-v2.onrender.com/api/health
