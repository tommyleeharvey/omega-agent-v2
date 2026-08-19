#!/data/data/com.termux/files/usr/bin/bash
set -x

echo "=== Looking for a stored Render API key (starts with rnd_) ==="
FOUND_KEY=$(grep -rhoE "rnd_[A-Za-z0-9]+" ~/omega_workspace ~/.env* ~/omega-agent-v2/.env* 2>/dev/null | head -1)

if [ -n "$FOUND_KEY" ]; then
  echo "Found a key in local files."
  RENDER_API_KEY="$FOUND_KEY"
elif [ -n "$RENDER_API_KEY" ]; then
  echo "Using RENDER_API_KEY from environment."
else
  echo "No Render API key found locally or in env."
  echo "Get one from: https://dashboard.render.com/u/settings#api-keys"
  echo "Then run: export RENDER_API_KEY=rnd_xxxxx && ~/omega_workspace/omega-agent-v2/check_render_deploy.sh"
  exit 1
fi

echo ""
echo "=== List services to find the omega-agent-backend-v2 service ID ==="
SERVICES=$(curl -s -H "Authorization: Bearer $RENDER_API_KEY" "https://api.render.com/v1/services?limit=50")
echo "$SERVICES" | python3 -m json.tool | head -100

SERVICE_ID=$(echo "$SERVICES" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for item in data:
    svc = item.get('service', item)
    name = svc.get('name', '')
    if 'omega' in name.lower() and 'backend' in name.lower():
        print(svc.get('id'))
        break
")
echo "Service ID: $SERVICE_ID"

if [ -z "$SERVICE_ID" ]; then
  echo "Could not auto-match the service by name - check the printed list above manually for the right id."
  exit 1
fi

echo ""
echo "=== Latest deploys for this service ==="
curl -s -H "Authorization: Bearer $RENDER_API_KEY" "https://api.render.com/v1/services/$SERVICE_ID/deploys?limit=5" | python3 -m json.tool

echo ""
echo "=== Latest deploy's detailed status ==="
LATEST_DEPLOY_ID=$(curl -s -H "Authorization: Bearer $RENDER_API_KEY" "https://api.render.com/v1/services/$SERVICE_ID/deploys?limit=1" | python3 -c "
import sys, json
data = json.load(sys.stdin)
print(data[0]['deploy']['id'])
")
echo "Latest deploy ID: $LATEST_DEPLOY_ID"
curl -s -H "Authorization: Bearer $RENDER_API_KEY" "https://api.render.com/v1/services/$SERVICE_ID/deploys/$LATEST_DEPLOY_ID" | python3 -m json.tool
