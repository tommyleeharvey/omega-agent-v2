#!/data/data/com.termux/files/usr/bin/bash
set -x
curl -s -H "Authorization: Bearer RENDER_TOKEN_HERE" \
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
