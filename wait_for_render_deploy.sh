#!/data/data/com.termux/files/usr/bin/bash
set -x
echo "=== Waiting for Render to pick up the new commit and redeploy ==="
sleep 60
curl -s -H "Authorization: Bearer rnd_vv9FVHwsb9nQr5Giy527Gq5LTAwa" \
  "https://api.render.com/v1/services/srv-da20pelg1s2s73de3n70/deploys?limit=3" \
  | python3 -c "
import sys, json
d = json.load(sys.stdin)
for dep in d:
    dep = dep.get('deploy', dep)
    print(dep.get('commit', {}).get('id', '')[:8], '-', dep.get('status'))
"
echo ""
echo "=== Confirm health endpoint responding ==="
curl -s https://omega-agent-backend-v2.onrender.com/api/health
