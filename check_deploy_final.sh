#!/data/data/com.termux/files/usr/bin/bash
set -x

RENDER_KEY=$(grep -oE "rnd_[A-Za-z0-9]{10,}" ~/omega-v2-pages-fix/.env | head -1)
SERVICE_ID="srv-da20pelg1s2s73de3n70"

for i in $(seq 1 20); do
  RESULT=$(curl -s -H "Authorization: Bearer $RENDER_KEY" \
    "https://api.render.com/v1/services/$SERVICE_ID/deploys?limit=1" | python3 -c "
import sys, json
data = json.load(sys.stdin)
d = data[0].get('deploy', data[0])
print(d.get('status'), '-', d.get('commit', {}).get('id','')[:8])
")
  echo "[$i] $RESULT"
  case "$RESULT" in
    live*) echo "DEPLOY LIVE"; break ;;
    build_failed*|update_failed*|deactivated*) echo "STILL FAILING"; break ;;
  esac
  sleep 15
done

echo ""
echo "=== Confirm the backend actually responds now ==="
curl -s -o /dev/null -w "HTTP %{http_code}\n" https://omega-agent-backend-v2.onrender.com/api/health
