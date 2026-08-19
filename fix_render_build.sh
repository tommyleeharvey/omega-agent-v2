#!/data/data/com.termux/files/usr/bin/bash
set -x

REPO=~/omega-agent-v2
cd "$REPO"

echo "=== Current requirements.txt ==="
cat requirements.txt

echo ""
echo "=== Remove chatterbox-tts (torch/torchaudio too heavy for Render free-tier build) ==="
sed -i '/^chatterbox-tts$/d' requirements.txt
cat requirements.txt

echo ""
echo "=== Make tts_service.py fail gracefully instead of crashing the app if chatterbox isn't installed ==="
python3 - << 'PYEOF'
path = "agent/tts_service.py"
with open(path) as f:
    content = f.read()

old = "        from chatterbox.tts import ChatterboxTTS\n        _model = ChatterboxTTS.from_pretrained(device=\"cpu\")"
new = (
    "        try:\n"
    "            from chatterbox.tts import ChatterboxTTS\n"
    "        except ImportError:\n"
    "            raise RuntimeError(\n"
    "                \"chatterbox-tts is not installed on this backend. \"\n"
    "                \"TTS needs a separate host with more build memory — \"\n"
    "                \"not this free-tier Render service.\"\n"
    "            )\n"
    "        _model = ChatterboxTTS.from_pretrained(device=\"cpu\")"
)

if old in content:
    content = content.replace(old, new)
    with open(path, "w") as f:
        f.write(content)
    print("Patched _get_model() to fail gracefully.")
else:
    print("Marker not found — tts_service.py may have changed, check manually.")
PYEOF

echo ""
echo "=== Commit and push the fix ==="
git add requirements.txt agent/tts_service.py
git status
git commit -m "fix: remove chatterbox-tts from requirements.txt (OOMs Render free-tier build) - TTS needs separate host"
git push origin main

echo ""
echo "=== Poll Render for the new deploy status ==="
RENDER_KEY=$(grep -oE "rnd_[A-Za-z0-9]{10,}" ~/omega-v2-pages-fix/.env | head -1)
SERVICE_ID="srv-da20pelg1s2s73de3n70"

for i in $(seq 1 15); do
  sleep 15
  STATUS=$(curl -s -H "Authorization: Bearer $RENDER_KEY" \
    "https://api.render.com/v1/services/$SERVICE_ID/deploys?limit=1" | python3 -c "
import sys, json
d = json.load(sys.stdin)[0].get('deploy', json.load(sys.stdin)[0]) if False else json.load(sys.stdin)
" 2>/dev/null)
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
    build_failed*|update_failed*) echo "STILL FAILING - check dashboard logs"; break ;;
  esac
done
