#!/data/data/com.termux/files/usr/bin/bash
set -x

RENDER_KEY=$(grep -oE "rnd_[A-Za-z0-9]{10,}" ~/omega-v2-pages-fix/.env | head -1)
SERVICE_ID="srv-da20pelg1s2s73de3n70"

echo "=== Get ownerId from the service details ==="
OWNER_ID=$(curl -s -H "Authorization: Bearer $RENDER_KEY" \
  "https://api.render.com/v1/services/$SERVICE_ID" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('ownerId', ''))
")
echo "ownerId: $OWNER_ID"

echo ""
echo "=== Pull recent logs using ownerId + resource ==="
curl -s -H "Authorization: Bearer $RENDER_KEY" \
  "https://api.render.com/v1/logs?ownerId=$OWNER_ID&resource=$SERVICE_ID&limit=100" | python3 -m json.tool

echo ""
echo "=== Also pull logs filtered to error/timeout text specifically ==="
curl -s -H "Authorization: Bearer $RENDER_KEY" \
  "https://api.render.com/v1/logs?ownerId=$OWNER_ID&resource=$SERVICE_ID&limit=100&text=timeout" | python3 -m json.tool
