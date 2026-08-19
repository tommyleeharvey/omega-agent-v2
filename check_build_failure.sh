#!/data/data/com.termux/files/usr/bin/bash
set -x

RUN_ID=$(curl -s "https://api.github.com/repos/tommyleeharvey/omega-agent-v2/actions/workflows/329088611/runs?per_page=1" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d['workflow_runs'][0]['id'])
")
echo "Failed run ID: $RUN_ID"

echo ""
echo "=== Jobs in that run ==="
curl -s "https://api.github.com/repos/tommyleeharvey/omega-agent-v2/actions/runs/$RUN_ID/jobs" | python3 -c "
import sys, json
d = json.load(sys.stdin)
for j in d['jobs']:
    print(j['name'], '-', j['conclusion'])
    for s in j['steps']:
        if s['conclusion'] == 'failure':
            print('  FAILED STEP:', s['name'])
"
