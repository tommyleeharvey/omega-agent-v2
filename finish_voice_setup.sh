#!/data/data/com.termux/files/usr/bin/bash
set -x
set -e

REPO=~/omega-agent-v2
cd "$REPO"

echo "=== Record the real 45s sample (test.wav worked, so this should too) ==="
rm -f voice_samples/test.wav
termux-microphone-record -f voice_samples/my_voice.wav -l 45
echo "Speak naturally for 45 seconds now - varied sentences, quiet room."
sleep 46
ls -lh voice_samples/my_voice.wav

echo ""
echo "=== Wire tts_bp into the real chat_server.py, right after the Flask app is created ==="
python3 - << 'PYEOF'
path = "agent/chat_server.py"
with open(path) as f:
    content = f.read()

marker = "app = Flask(__name__)"
if "from agent.tts_service import tts_bp" in content:
    print("Already wired, skipping.")
else:
    insertion = marker + "\n\nfrom agent.tts_service import tts_bp\napp.register_blueprint(tts_bp)"
    if marker not in content:
        raise SystemExit("Marker not found - chat_server.py may have changed, wire manually.")
    content = content.replace(marker, insertion, 1)
    with open(path, "w") as f:
        f.write(content)
    print("Wired tts_bp into chat_server.py")
PYEOF

echo ""
echo "=== Confirm the wiring landed ==="
grep -n -A2 "app = Flask(__name__)" agent/chat_server.py

echo ""
echo "=== Install deps locally so we can smoke-test before pushing ==="
pip install -r requirements.txt --break-system-packages -q

echo ""
echo "=== Smoke test: import the app, confirm /api/tts route registered ==="
python3 -c "
import sys
sys.path.insert(0, '.')
from agent.chat_server import app
routes = [str(r) for r in app.url_map.iter_rules()]
print('\n'.join(routes))
assert any('/api/tts' in r for r in routes), 'tts route missing!'
print('OK: /api/tts is registered')
"

echo ""
echo "=== Commit and push ==="
git add requirements.txt agent/tts_service.py agent/chat_server.py .gitignore 2>/dev/null || git add requirements.txt agent/tts_service.py agent/chat_server.py
git status
git commit -m "feat: add Chatterbox TTS endpoint, wire into chat_server.py"
git push origin main

echo ""
echo "=== NOTE: voice_samples/my_voice.wav is your biometric voice data - make sure .gitignore excludes it before this push if you don't want it in a public repo ==="
grep -q "voice_samples" .gitignore 2>/dev/null && echo "Already gitignored - good" || echo "NOT gitignored - check this before the commit above runs again"
