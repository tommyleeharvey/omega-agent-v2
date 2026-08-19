#!/data/data/com.termux/files/usr/bin/bash
set -x

curl -s -H "Authorization: Bearer rnd_vv9FVHwsb9nQr5Giy527Gq5LTAwa" \
  "https://api.render.com/v1/logs?ownerId=tea-cumojslumphs738ld8fg&resource=srv-da20pelg1s2s73de3n70&limit=150" \
  > /data/data/com.termux/files/home/failed_job.json

python3 - << 'PYEOF'
import json
with open("/data/data/com.termux/files/home/failed_job.json") as f:
    d = json.load(f)

logs = d.get("logs") or []
entries = sorted(((l["timestamp"], l["message"]) for l in logs))

for ts, msg in entries[-60:]:
    print(ts, "|", msg)
PYEOF
