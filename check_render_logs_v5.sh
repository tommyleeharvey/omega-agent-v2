#!/data/data/com.termux/files/usr/bin/bash
cd ~/omega-agent-v2

TOKEN=$(grep -oP "(?<=Bearer )[a-zA-Z0-9_-]+" apply_gemini_key.sh | head -1)

if [ -z "$TOKEN" ]; then
  echo "Could not find token."
  exit 1
fi

echo "=== fetching owner id from the service info ==="
curl -s -H "Authorization: Bearer $TOKEN" \
  "https://api.render.com/v1/services/srv-da20pelg1s2s73de3n70" \
  > service_info.json 2>&1

OWNER_ID=$(python3 -c "
import json
with open('service_info.json') as f:
    d = json.load(f)
print(d.get('ownerId', ''))
")

echo "ownerId found: $([ -n "$OWNER_ID" ] && echo yes || echo no)"
rm -f service_info.json

if [ -z "$OWNER_ID" ]; then
  echo "Could not extract ownerId - dumping raw service info shape instead:"
  curl -s -H "Authorization: Bearer $TOKEN" \
    "https://api.render.com/v1/services/srv-da20pelg1s2s73de3n70" | head -c 500
  exit 1
fi

echo ""
echo "=== fetching logs with ownerId ==="
curl -s -H "Authorization: Bearer $TOKEN" \
  "https://api.render.com/v1/logs?resource=srv-da20pelg1s2s73de3n70&ownerId=$OWNER_ID&limit=50" \
  > raw_render_logs.json 2>&1

echo "=== raw response, first 1500 chars ==="
head -c 1500 raw_render_logs.json
echo ""
rm -f raw_render_logs.json
