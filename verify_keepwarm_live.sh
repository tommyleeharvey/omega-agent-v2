#!/data/data/com.termux/files/usr/bin/bash
set -x

echo "=== Confirm the keepwarm workflow is registered on GitHub ==="
curl -s "https://api.github.com/repos/tommyleeharvey/omega-agent-v2/actions/workflows" | python3 -c "
import sys, json
d = json.load(sys.stdin)
for wf in d.get('workflows', []):
    print(wf['id'], '-', wf['name'], '-', wf['state'])
"

echo ""
echo "=== Manually trigger it right now via workflow_dispatch ==="
WORKFLOW_ID=$(curl -s "https://api.github.com/repos/tommyleeharvey/omega-agent-v2/actions/workflows" | python3 -c "
import sys, json
d = json.load(sys.stdin)
for wf in d.get('workflows', []):
    if wf['name'] == 'keep-backend-warm':
        print(wf['id'])
")
echo "Workflow ID: $WORKFLOW_ID"

curl -s -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: token ${GITHUB_TOKEN:-}" \
  "https://api.github.com/repos/tommyleeharvey/omega-agent-v2/actions/workflows/$WORKFLOW_ID/dispatches" \
  -d '{"ref":"main"}'

echo ""
echo "=== Test the live site right now regardless (may still be cold on this first hit) ==="
python3 -c "
import requests, time
try:
    start = time.time()
    r = requests.post('https://omega-agent-backend-v2.onrender.com/api/chat', json={'message':'Hi'}, timeout=90)
    print('status', r.status_code, '- took', round(time.time()-start,1), 'seconds')
    print('body', r.text[:300])
except Exception as e:
    print('err', e)
"
