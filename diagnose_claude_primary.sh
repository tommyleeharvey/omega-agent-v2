#!/data/data/com.termux/files/usr/bin/bash
set -x

REPO=~/omega-agent-v2
cd "$REPO"

echo "=== 1) Confirm ANTHROPIC_API_KEY is actually set on Render (not just locally) ==="
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
echo "=== 2) Show claude_client.py to see how it fails ==="
cat -n api/claude_client.py

echo ""
echo "=== 3) Pull logs specifically for 'Claude primary failed' warning ==="
curl -s -H "Authorization: Bearer rnd_vv9FVHwsb9nQr5Giy527Gq5LTAwa" \
  "https://api.render.com/v1/logs?ownerId=tea-cumojslumphs738ld8fg&resource=srv-da20pelg1s2s73de3n70&limit=300&text=Claude" \
  | python3 -m json.tool
