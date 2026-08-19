#!/data/data/com.termux/files/usr/bin/bash
set -x

REPO=~/omega-agent-v2
cd "$REPO"

echo "=== Context after both response.data assignments, through where it hits setMessages ==="
sed -n '405,460p' src/pages/Home.jsx
