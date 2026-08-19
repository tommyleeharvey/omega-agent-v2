#!/data/data/com.termux/files/usr/bin/bash
set -x

REPO=~/omega-agent-v2
cd "$REPO"
TS=$(date +%Y%m%d-%H%M%S)
cp api/groq_client.py "api/groq_client.py.bak-$TS"

echo "=== 1) Create Cerebras client (OpenAI-compatible, same shape as Groq) ==="
cat > api/cerebras_client.py << 'CEREOF'
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
CEREOF
echo "cerebras_client.py created."

echo ""
echo "=== 2) Wire Cerebras in after Gemini, before Groq tier stack ==="
python3 - << 'PYEOF'
path = "api/groq_client.py"
with open(path) as f:
    content = f.read()

old_import = "from api import gemini_client"
new_import = "from api import gemini_client\nfrom api import cerebras_client"
if old_import in content:
    content = content.replace(old_import, new_import)
    print("Import added.")
else:
    print("MANUAL: gemini import line not found")
    raise SystemExit

old_gemini_block = '''    if _tier_start_index == 0 and os.environ.get("GEMINI_API_KEY"):
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

new_gemini_block = '''    if _tier_start_index == 0 and os.environ.get("GEMINI_API_KEY"):
        try:
            gemini_result = gemini_client.chat_completion(
                messages,
                max_tokens=max_tokens,
                tools=tools,
                return_message=True,
            )
            return gemini_result if return_message else gemini_result.get("content", "")
        except Exception as exc:
            logger.warning("Gemini failed; trying Cerebras: %s", exc)

    if _tier_start_index == 0 and os.environ.get("CEREBRAS_API_KEY"):
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

count = content.count(old_gemini_block)
print(f"Exact match occurrences: {count}")
if count == 1:
    content = content.replace(old_gemini_block, new_gemini_block)
    with open(path, "w") as f:
        f.write(content)
    print("Cerebras wired in as third brain.")
else:
    print("MANUAL: gemini block not found, aborting.")
    raise SystemExit
PYEOF

echo ""
echo "=== 3) Prompt for Cerebras key and set on Render ==="
echo "Get a free key at https://cloud.cerebras.ai/ (Platform > API Keys) if you don't have one."
read -sp "CEREBRAS_API_KEY: " CEREBRAS_KEY
echo ""

curl -s -X PUT \
  -H "Authorization: Bearer rnd_vv9FVHwsb9nQr5Giy527Gq5LTAwa" \
  -H "Content-Type: application/json" \
  "https://api.render.com/v1/services/srv-da20pelg1s2s73de3n70/env-vars/CEREBRAS_API_KEY" \
  -d "{\"value\": \"$CEREBRAS_KEY\"}"

echo ""
echo "=== 4) Show diff, commit, push ==="
git diff api/groq_client.py
git status --short api/cerebras_client.py
git add api/cerebras_client.py api/groq_client.py
git commit -m "feat: add Cerebras as third-tier brain (Claude -> Gemini -> Cerebras -> Groq), not caught in Gemini's AQ-key rollout issue"
git push origin main

echo ""
echo "=== 5) Trigger redeploy, wait, confirm ==="
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
