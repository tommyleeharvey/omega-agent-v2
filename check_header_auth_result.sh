#!/data/data/com.termux/files/usr/bin/bash
set -x

curl -s -H "Authorization: Bearer rnd_vv9FVHwsb9nQr5Giy527Gq5LTAwa" \
  "https://api.render.com/v1/logs?ownerId=tea-cumojslumphs738ld8fg&resource=srv-da20pelg1s2s73de3n70&limit=150" \
  > /data/data/com.termux/files/home/header_auth_check.json

python3 - << 'PYEOF'
import json
with open("/data/data/com.termux/files/home/header_auth_check.json") as f:
    d = json.load(f)

logs = d.get("logs") or []
entries = sorted(((l["timestamp"], l["message"]) for l in logs))

gemini_lines = [(ts, msg) for ts, msg in entries if "Gemini" in msg or "gemini" in msg]

if not gemini_lines:
    print("No Gemini-related log lines in this window - send a chat message first, then rerun.")
else:
    for ts, msg in gemini_lines[-30:]:
        print(ts, "|", msg[:300])
PYEOF
