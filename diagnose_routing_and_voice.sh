#!/data/data/com.termux/files/usr/bin/bash
set -x
cd ~/omega-agent-v2

echo "=== 1) the tier stack order, wherever it's defined ==="
grep -rn "GEMINI\|gemini" api/groq_client.py | head -20

echo ""
echo "=== 2) full tier selection function ==="
grep -n "def chat_completion\|def.*tier\|TIER" api/groq_client.py

echo ""
echo "=== 3) is Gemini actually being attempted, and what error does it throw ==="
grep -n "gemini" api/*.py -ri | head -30

echo ""
echo "=== 4) current voice/TTS wiring state ==="
find agent api -iname "*tts*" -o -iname "*voice*" 2>/dev/null
grep -rln "chatterbox\|elevenlabs\|voice_clone\|speaker_id" agent/ api/ 2>/dev/null

echo ""
echo "=== 5) any existing voice sample files or model refs ==="
find . -maxdepth 2 -iname "*voice*" -o -iname "*.wav" -o -iname "*.mp3" 2>/dev/null | grep -v node_modules
