#!/data/data/com.termux/files/usr/bin/bash
set -x
echo "Paste your NEW Anthropic key below when prompted (from https://console.anthropic.com/settings/keys)"
read -sp "New ANTHROPIC_API_KEY: " NEW_KEY
echo ""

curl -s -X PUT \
  -H "Authorization: Bearer rnd_vv9FVHwsb9nQr5Giy527Gq5LTAwa" \
  -H "Content-Type: application/json" \
  "https://api.render.com/v1/services/srv-da20pelg1s2s73de3n70/env-vars/ANTHROPIC_API_KEY" \
  -d "{\"value\": \"$NEW_KEY\"}"

echo ""
echo "=== Trigger redeploy ==="
curl -s -X POST \
  -H "Authorization: Bearer rnd_vv9FVHwsb9nQr5Giy527Gq5LTAwa" \
  "https://api.render.com/v1/services/srv-da20pelg1s2s73de3n70/deploys" \
  | python3 -m json.tool

sleep 45
echo "=== Confirm live and test the key actually authenticates ==="
curl -s https://omega-agent-backend-v2.onrender.com/api/health
