#!/data/data/com.termux/files/usr/bin/bash
set -x

RENDER_KEY=$(grep -oE "rnd_[A-Za-z0-9]{10,}" ~/omega-v2-pages-fix/.env | head -1)
SERVICE_ID="srv-da20pelg1s2s73de3n70"

curl -s -H "Authorization: Bearer $RENDER_KEY" \
  "https://api.render.com/v1/logs?resource=$SERVICE_ID&limit=100" | python3 -m json.tool
