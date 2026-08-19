#!/data/data/com.termux/files/usr/bin/bash
set -x

curl -s -H "Authorization: Bearer rnd_vv9FVHwsb9nQr5Giy527Gq5LTAwa" \
  "https://api.render.com/v1/logs?ownerId=tea-cumojslumphs738ld8fg&resource=srv-da20pelg1s2s73de3n70&limit=300" \
  > /data/data/com.termux/files/home/fresh_logs2.json

python3 - << 'PYEOF'
import json
with open("/data/data/com.termux/files/home/fresh_logs2.json") as f:
    d = json.load(f)

logs = d.get("logs") or []
entries = sorted(((l["timestamp"], l["message"]) for l in logs))

# print everything from 05:05:20 to 05:05:40 - the second failed job's full window
for ts, msg in entries:
    if "2026-08-19T05:05:2" in ts or "2026-08-19T05:05:3" in ts:
        print(ts, "|", msg[:300])
PYEOF
