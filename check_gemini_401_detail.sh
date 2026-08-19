#!/data/data/com.termux/files/usr/bin/bash
cd ~/omega-agent-v2

TOKEN=$(grep -oP "(?<=Bearer )[a-zA-Z0-9_-]+" apply_gemini_key.sh | head -1)
OWNER_ID=$(curl -s -H "Authorization: Bearer $TOKEN" \
  "https://api.render.com/v1/services/srv-da20pelg1s2s73de3n70" \
  | python3 -c "import json,sys; print(json.load(sys.stdin).get('ownerId',''))")

curl -s -H "Authorization: Bearer $TOKEN" \
  "https://api.render.com/v1/logs?resource=srv-da20pelg1s2s73de3n70&ownerId=$OWNER_ID&limit=100" \
  > raw_logs3.json

echo "=== full Gemini 401 error body ==="
python3 -c "
import json
with open('raw_logs3.json') as f:
    d = json.load(f)
for entry in d.get('logs', []):
    msg = entry.get('message', '')
    if 'Gemini failed' in msg:
        print(msg)
        print('---')
        break
"
rm -f raw_logs3.json
