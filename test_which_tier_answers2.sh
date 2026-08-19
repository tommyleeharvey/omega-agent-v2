#!/data/data/com.termux/files/usr/bin/bash
set -x
curl -s -X POST https://omega-agent-backend-v2.onrender.com/api/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "In one word, what AI model or company made you? Just the name, nothing else."}' \
  | python3 -m json.tool
echo ""
