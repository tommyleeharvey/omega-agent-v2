#!/data/data/com.termux/files/usr/bin/bash
set -x

echo "=== Locate a Render API key (rnd_...) on this device ==="
RENDER_KEY=""
for f in ~/omega-v2-pages-fix/.env ~/omega-agent-v2/.env ~/.render_key ~/omega_workspace/*/.env; do
  if [ -f "$f" ]; then
    MATCH=$(grep -oE "rnd_[A-Za-z0-9]{10,}" "$f" 2>/dev/null | head -1)
    if [ -n "$MATCH" ]; then
      echo "Found key in $f"
      RENDER_KEY="$MATCH"
      break
    fi
  fi
done

if [ -z "$RENDER_KEY" ]; then
  echo "No rnd_ key found in the usual spots. Wider search:"
  grep -rlE "rnd_[A-Za-z0-9]{10,}" ~/ 2>/dev/null | grep -v node_modules | grep -v "/\.git/"
  echo "If found above, re-run this script after adding that path to the loop,"
  echo "or export it manually: export RENDER_KEY=rnd_xxxxx"
  exit 1
fi

echo ""
echo "=== List Render services tied to this account ==="
curl -s -H "Authorization: Bearer $RENDER_KEY" \
  "https://api.render.com/v1/services?limit=20" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for item in data:
    s = item.get('service', item)
    print(s.get('id'), '-', s.get('name'), '-', s.get('type'))
"

echo ""
echo "=== Find the omega-agent-backend-v2 service id specifically ==="
SERVICE_ID=$(curl -s -H "Authorization: Bearer $RENDER_KEY" \
  "https://api.render.com/v1/services?limit=20" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for item in data:
    s = item.get('service', item)
    if 'omega' in s.get('name','').lower() and 'backend' in s.get('name','').lower():
        print(s.get('id'))
        break
")
echo "SERVICE_ID=$SERVICE_ID"

if [ -z "$SERVICE_ID" ]; then
  echo "Could not auto-match the service by name — check the full list printed above"
  echo "and re-run with: export SERVICE_ID=srv-xxxxx"
  exit 1
fi

echo ""
echo "=== Latest deploys for this service ==="
curl -s -H "Authorization: Bearer $RENDER_KEY" \
  "https://api.render.com/v1/services/$SERVICE_ID/deploys?limit=5" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for item in data:
    d = item.get('deploy', item)
    print(d.get('id'), '-', d.get('status'), '-', d.get('createdAt'), '-', d.get('commit', {}).get('id','')[:8])
"

echo ""
echo "=== Get the most recent (failed) deploy's ID and pull its build logs ==="
LATEST_DEPLOY=$(curl -s -H "Authorization: Bearer $RENDER_KEY" \
  "https://api.render.com/v1/services/$SERVICE_ID/deploys?limit=1" | python3 -c "
import sys, json
data = json.load(sys.stdin)
print(data[0].get('deploy', data[0]).get('id'))
")
echo "LATEST_DEPLOY=$LATEST_DEPLOY"

curl -s -H "Authorization: Bearer $RENDER_KEY" \
  "https://api.render.com/v1/services/$SERVICE_ID/deploys/$LATEST_DEPLOY" | python3 -m json.tool

echo ""
echo "=== NOTE: Render's build-log text isn't always exposed via this API endpoint —"
echo "if the above doesn't show a clear error, open the Render dashboard > this"
echo "service > the failed deploy > Logs tab for the full build output."
echo ""
echo "=== Likely cause to check first: chatterbox-tts in requirements.txt ==="
echo "chatterbox-tts pulls in torch/torchaudio, which are large and can blow past"
echo "Render's free-tier build memory/time limits. If the logs show an OOM kill,"
echo "a pip build timeout, or 'killed' during the chatterbox-tts/torch install step,"
echo "that's the cause — TTS needs a separate host, not this same free backend."
