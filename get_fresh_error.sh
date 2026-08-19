#!/data/data/com.termux/files/usr/bin/bash
set -x

echo "=== Pull logs from just the last few minutes, since the fix deployed ==="
curl -s -H "Authorization: Bearer rnd_vv9FVHwsb9nQr5Giy527Gq5LTAwa" \
  "https://api.render.com/v1/logs?ownerId=tea-cumojslumphs738ld8fg&resource=srv-da20pelg1s2s73de3n70&limit=300" \
  > /data/data/com.termux/files/home/fresh_logs.json

python3 - << 'PYEOF'
import json
from datetime import datetime, timezone

with open("/data/data/com.termux/files/home/fresh_logs.json") as f:
    d = json.load(f)

logs = d.get("logs") or []
# only look at logs from the last ~15 minutes
cutoff_str = None
recent = []
for l in logs:
    ts = l.get("timestamp", "")
    recent.append((ts, l["message"]))

recent.sort()
recent = recent[-150:]  # last 150 lines regardless of time, most recent window

for ts, msg in recent:
    if any(k in msg for k in ["Error", "Traceback", "error", "Exception", "raise", "WORKER TIMEOUT", "SIGKILL", "Killed"]):
        print(ts, "|", msg[:300])
PYEOF
