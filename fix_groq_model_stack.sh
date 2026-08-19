#!/data/data/com.termux/files/usr/bin/bash
set -x

REPO=~/omega-agent-v2
cd "$REPO"

echo "=== 1) Find where the 5-tier model stack is defined ==="
grep -rn "llama-3.1-8b-instant\|llama-3.3-70b-versatile\|MODEL_TIERS\|model_tiers\|FALLBACK" agent/ 2>/dev/null

echo ""
echo "=== 2) List current live Groq models on this key, so we don't guess wrong names ==="
GROQ_KEY=$(grep -oE '^GROQ_API_KEY=.*' .env 2>/dev/null | cut -d= -f2)
if [ -z "$GROQ_KEY" ]; then
  GROQ_KEY=$(grep -oE '^GROQ_API_KEY=.*' ~/.omega/.env 2>/dev/null | cut -d= -f2)
fi
if [ -n "$GROQ_KEY" ]; then
  curl -s -H "Authorization: Bearer $GROQ_KEY" "https://api.groq.com/openai/v1/models" | python3 -c "
import sys, json
d = json.load(sys.stdin)
for m in d.get('data', []):
    print(m['id'])
"
else
  echo "MANUAL: no GROQ_API_KEY found in .env or ~/.omega/.env"
fi
