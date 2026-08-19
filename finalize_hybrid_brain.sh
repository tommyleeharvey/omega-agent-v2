#!/data/data/com.termux/files/usr/bin/bash
set -x

echo "=== 1) Set Gemini key ==="
curl -s -X PUT \
  -H "Authorization: Bearer rnd_vv9FVHwsb9nQr5Giy527Gq5LTAwa" \
  -H "Content-Type: application/json" \
  "https://api.render.com/v1/services/srv-da20pelg1s2s73de3n70/env-vars/GEMINI_API_KEY" \
  -d '{"value": "AQ.Ab8RN6KpA54ExIifVt3x3x03S8V0NxA0IVDlSEdB3ucRn8W07A"}'

echo ""
echo "=== 2) Remove dead ANTHROPIC_API_KEY so the code skips it instantly instead of failing every call ==="
curl -s -X DELETE \
  -H "Authorization: Bearer rnd_vv9FVHwsb9nQr5Giy527Gq5LTAwa" \
  "https://api.render.com/v1/services/srv-da20pelg1s2s73de3n70/env-vars/ANTHROPIC_API_KEY"

echo ""
echo "=== 3) Trigger redeploy ==="
curl -s -X POST \
  -H "Authorization: Bearer rnd_vv9FVHwsb9nQr5Giy527Gq5LTAwa" \
  "https://api.render.com/v1/services/srv-da20pelg1s2s73de3n70/deploys" \
  | python3 -m json.tool

echo ""
echo "=== 4) Wait, confirm env vars and live status ==="
sleep 45
curl -s -H "Authorization: Bearer rnd_vv9FVHwsb9nQr5Giy527Gq5LTAwa" \
  "https://api.render.com/v1/services/srv-da20pelg1s2s73de3n70/env-vars" \
  | python3 -c "
import sys, json
d = json.load(sys.stdin)
for e in d:
    ev = e.get('envVar', e)
    print(ev.get('key'), '- SET' if ev.get('value') else '- EMPTY')
"
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
