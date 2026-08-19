#!/data/data/com.termux/files/usr/bin/bash
cd ~/omega-agent-v2

TOKEN=$(grep -oP "(?<=Bearer )[a-zA-Z0-9_-]+" apply_gemini_key.sh | head -1)

if [ -z "$TOKEN" ]; then
  echo "Could not find token."
  exit 1
fi

curl -s -H "Authorization: Bearer $TOKEN" \
  "https://api.render.com/v1/logs?resource=srv-da20pelg1s2s73de3n70&limit=50" \
  > raw_render_logs.json 2>&1

echo "=== raw response, first 800 chars ==="
head -c 800 raw_render_logs.json
echo ""
rm -f raw_render_logs.json
