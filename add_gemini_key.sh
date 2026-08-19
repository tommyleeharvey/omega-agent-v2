#!/data/data/com.termux/files/usr/bin/bash
set -x
cd ~/omega-agent-v2

if [ -z "$1" ]; then
  echo "Usage: ./add_gemini_key.sh YOUR_GEMINI_API_KEY"
  exit 1
fi

if grep -q "^GEMINI_API_KEY=" .env; then
  echo "GEMINI_API_KEY already exists in .env - not touching it, edit manually if it's wrong."
else
  echo "GEMINI_API_KEY=$1" >> .env
  echo "Added."
fi

grep "GEMINI_API_KEY" .env
