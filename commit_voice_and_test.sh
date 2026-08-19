#!/data/data/com.termux/files/usr/bin/bash
set -x

REPO=~/omega-agent-v2
cd "$REPO"

echo "=== Remove voice_samples/ from .gitignore so the sample can be committed ==="
sed -i '/^voice_samples\/$/d' .gitignore
cat .gitignore

echo ""
echo "=== Commit and push the actual voice sample ==="
git add .gitignore
git add -f voice_samples/my_voice.wav
git status
git commit -m "Add voice sample for Chatterbox TTS cloning"
git push origin main

echo ""
echo "=== Wait for Render to pick up the deploy (Render auto-deploys on push if connected to this repo) ==="
sleep 30

echo ""
echo "=== Test the live TTS endpoint - this will trigger the first Chatterbox model download, expect it to be slow (could be 1-5+ minutes) ==="
python3 -c "
import requests, time
try:
    start = time.time()
    r = requests.post(
        'https://omega-agent-backend-v2.onrender.com/api/tts',
        json={'text': 'Hello, this is a test of my own voice.'},
        timeout=300
    )
    elapsed = round(time.time() - start, 1)
    print('status', r.status_code, '- took', elapsed, 'seconds')
    if r.status_code == 200:
        with open('voice_samples/tts_test_output.wav', 'wb') as f:
            f.write(r.content)
        print('Saved response audio to voice_samples/tts_test_output.wav -', len(r.content), 'bytes')
    else:
        print('body:', r.text[:500])
except Exception as e:
    print('err', e)
"
