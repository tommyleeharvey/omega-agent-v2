#!/data/data/com.termux/files/usr/bin/bash
set -x

REPO=~/omega-agent-v2
cd "$REPO"

echo "=== Continue from where the last view cut off, through the next setMessages call ==="
sed -n '460,510p' src/pages/Home.jsx

echo ""
echo "=== Just in case there are multiple setMessages calls with 'content', list all of them ==="
grep -n "setMessages" src/pages/Home.jsx
