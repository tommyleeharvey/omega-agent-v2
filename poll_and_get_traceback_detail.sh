#!/data/data/com.termux/files/usr/bin/bash
set -x

echo "=== Poll latest build ==="
sleep 15
curl -s "https://api.github.com/repos/tommyleeharvey/omega-agent-v2/actions/workflows/329088611/runs?per_page=3" | python3 -c "
import sys, json
d = json.load(sys.stdin)
for r in d.get('workflow_runs', []):
    print(r['created_at'], '-', r['status'], '-', r['conclusion'], '-', r['head_sha'][:8])
"

echo ""
echo "=== Get the actual exception type/message, not just the 'Traceback' header line ==="
echo "=== Pulling a wider window and filtering for lines that look like Python exceptions ==="
curl -s -H "Authorization: Bearer rnd_vv9FVHwsb9nQr5Giy527Gq5LTAwa" \
  "https://api.render.com/v1/logs?ownerId=tea-cumojslumphs738ld8fg&resource=srv-da20pelg1s2s73de3n70&limit=300" \
  > /data/data/com.termux/files/home/full_logs.json

python3 - << 'PYEOF'
import json
with open("/data/data/com.termux/files/home/full_logs.json") as f:
    d = json.load(f)

logs = d.get("logs") or []
msgs = [l["message"] for l in logs]

# find lines that look like "SomethingError: message" (typical last line of a traceback)
import re
error_pattern = re.compile(r'^[A-Za-z_.]*Error[A-Za-z]*:')
seen = set()
for m in msgs:
    if error_pattern.match(m.strip()):
        if m not in seen:
            seen.add(m)
            print(m)

print("---")
print(f"Total distinct exception messages found: {len(seen)}")
PYEOF
