#!/data/data/com.termux/files/usr/bin/bash
set -x
cd ~/omega-agent-v2

echo "=== 1) _tier_start_index: where it's defined, set, and reset ==="
grep -n "_tier_start_index" api/groq_client.py

echo ""
echo "=== 2) full chat_completion function body ==="
sed -n '122,200p' api/groq_client.py

echo ""
echo "=== 3) is GEMINI_API_KEY actually set on this machine's env right now ==="
if [ -n "$GEMINI_API_KEY" ]; then echo "SET locally (length: ${#GEMINI_API_KEY})"; else echo "NOT SET locally"; fi
grep -c "GEMINI_API_KEY" .env 2>/dev/null || echo ".env has no GEMINI_API_KEY line"

echo ""
echo "=== 4) full tts_service.py ==="
cat -n agent/tts_service.py

echo ""
echo "=== 5) is tts_service wired into chat_server.py or agent_loop.py at all? ==="
grep -rn "tts_service\|from agent.tts\|import tts" agent/*.py

echo ""
echo "=== 6) is there a frontend TTS/voice call anywhere in src/? ==="
grep -rln "speak\|tts\|voice" src/ --include="*.jsx" --include="*.js" | grep -vi node_modules
