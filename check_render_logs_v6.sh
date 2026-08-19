#!/data/data/com.termux/files/usr/bin/bash
cd ~/omega-agent-v2

TOKEN=$(grep -oP "(?<=Bearer )[a-zA-Z0-9_-]+" apply_gemini_key.sh | head -1)
OWNER_ID=$(curl -s -H "Authorization: Bearer $TOKEN" \
  "https://api.render.com/v1/services/srv-da20pelg1s2s73de3n70" \
  | python3 -c "import json,sys; print(json.load(sys.stdin).get('ownerId',''))")

curl -s -H "Authorization: Bearer $TOKEN" \
  "https://api.render.com/v1/logs?resource=srv-da20pelg1s2s73de3n70&ownerId=$OWNER_ID&limit=100" \
  > raw_logs2.json

echo "=== lines mentioning Claude/Gemini/Cerebras/OpenRouter tier attempts ==="
python3 -c "
import json
with open('raw_logs2.json') as f:
    d = json.load(f)
for entry in d.get('logs', []):
    msg = entry.get('message', '')
    if any(k in msg for k in ['Claude failed', 'Gemini failed', 'Cerebras failed', 'OpenRouter failed', 'trying Gemini', 'trying Cerebras', 'trying OpenRouter']):
        print(entry.get('timestamp',''), '-', msg)
"
rm -f raw_logs2.json
