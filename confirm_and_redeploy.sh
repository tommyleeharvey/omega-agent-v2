#!/data/data/com.termux/files/usr/bin/bash
set -x

echo "=== Confirm ANTHROPIC_API_KEY is now set ==="
curl -s -H "Authorization: Bearer rnd_vv9FVHwsb9nQr5Giy527Gq5LTAwa" \
  "https://api.render.com/v1/services/srv-da20pelg1s2s73de3n70/env-vars" \
  | python3 -c "
import sys, json
d = json.load(sys.stdin)
for e in d:
    ev = e.get('envVar', e)
    print(ev.get('key'), '- SET' if ev.get('value') else '- EMPTY')
"

echo ""
echo "=== Trigger a manual redeploy so the running gunicorn process picks up the new env var ==="
curl -s -X POST \
  -H "Authorization: Bearer rnd_vv9FVHwsb9nQr5Giy527Gq5LTAwa" \
  "https://api.render.com/v1/services/srv-da20pelg1s2s73de3n70/deploys" \
  | python3 -m json.tool

echo ""
echo "=== Wait, then confirm deploy landed and health check passes ==="
sleep 60
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
