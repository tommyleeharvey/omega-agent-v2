#!/data/data/com.termux/files/usr/bin/bash
set -x

curl -s -X PUT \
  -H "Authorization: Bearer rnd_vv9FVHwsb9nQr5Giy527Gq5LTAwa" \
  -H "Content-Type: application/json" \
  "https://api.render.com/v1/services/srv-da20pelg1s2s73de3n70/env-vars/GEMINI_API_KEY" \
  -d '{"value": "AQ.Ab8RN6KpA54ExIifVt3x3x03S8V0NxA0IVDlSEdB3ucRn8W07A"}'

echo ""
echo "=== Trigger redeploy ==="
curl -s -X POST \
  -H "Authorization: Bearer rnd_vv9FVHwsb9nQr5Giy527Gq5LTAwa" \
  "https://api.render.com/v1/services/srv-da20pelg1s2s73de3n70/deploys" \
  | python3 -m json.tool

echo ""
echo "=== Wait, confirm live ==="
sleep 45
curl -s -H "Authorization: Bearer rnd_vv9FVHwsb9nQr5Giy527Gq5LTAwa" \
  "https://api.render.com/v1/services/srv-da20pelg1s2s73de3n70/deploys?limit=2" \
  | python3 -c "
import sys, json
d = json.load(sys.stdin)
for dep in d:
    dep = dep.get('deploy', dep)
    print(dep.get('commit', {}).get('id', '')[:8], '-', dep.get('status'))
"
curl -s https://omega-agent-backend-v2.onrender.com/api/health
