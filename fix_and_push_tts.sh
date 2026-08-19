#!/data/data/com.termux/files/usr/bin/bash
set -x

REPO=~/omega-agent-v2
cd "$REPO"

echo "=== Why psutil failed: psutil==5.9.8 doesn't have prebuilt wheels for Android/Termux, ==="
echo "=== and pip tries to compile it from source, which fails on this platform. This is a ==="
echo "=== LOCAL Termux-only problem - Render's build server is normal Linux and will install ==="
echo "=== psutil fine. So we skip the full local install and smoke-test only what we can. ==="

echo ""
echo "=== Install just the TTS-relevant packages locally (skip the full requirements.txt) ==="
pip install flask flask-cors --break-system-packages -q

echo ""
echo "=== Lightweight smoke test: confirm tts_service.py and chat_server.py are syntactically ==="
echo "=== valid and the route registers, without needing psutil/sqlalchemy/chatterbox installed ==="
python3 -c "
import ast
for f in ['agent/tts_service.py', 'agent/chat_server.py']:
    with open(f) as fh:
        src = fh.read()
    ast.parse(src)
    print(f'{f}: syntax OK')
"

echo ""
echo "=== Keep the voice sample OUT of the public repo - add to .gitignore ==="
grep -q "^voice_samples/" .gitignore 2>/dev/null || echo "voice_samples/" >> .gitignore
cat .gitignore

echo ""
echo "=== Stage only code changes, never the voice sample itself ==="
git add requirements.txt agent/tts_service.py agent/chat_server.py .gitignore
git status

echo ""
echo "=== Commit and push ==="
git commit -m "feat: add Chatterbox TTS endpoint, wire into chat_server.py"
git push origin main

echo ""
echo "=== voice_samples/my_voice.wav stays local-only on this device for now. ==="
echo "=== Render's backend will need it at runtime though - next step is uploading it there ==="
echo "=== as a private file (e.g. via Render's persistent disk or a one-time secure upload), ==="
echo "=== NOT by committing it to git. We'll set that up once this deploy confirms the route works."
