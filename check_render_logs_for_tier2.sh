#!/data/data/com.termux/files/usr/bin/bash
set -x
cd ~/omega-agent-v2

TOKEN=$(grep -oP "(?<=Bearer )[a-zA-Z0-9_-]+" apply_gemini_key.sh | head -1)

if [ -z "$TOKEN" ]; then
  echo "Could not find token in apply_gemini_key.sh - paste it manually instead."
  exit 1
fi

curl -s -H "Authorization: Bearer $TOKEN" \
  "https://api.render.com/v1/services/srv-da20pelg1s2s73de3n70/logs?limit=50" \
  | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    for entry in d:
        text = entry.get('message', entry) if isinstance(entry, dict) else entry
        print(text)
except Exception as e:
    print('parse error:', e)
    print(sys.stdin.read())
"
