#!/data/data/com.termux/files/usr/bin/bash
set -x

REPO=~/omega-agent-v2
cd "$REPO"

echo "=== Fetch latest and check what e45aece2 actually is ==="
git fetch origin
git log --oneline -5 origin/main

echo ""
echo "=== Show the diff of that commit specifically ==="
git show --stat e45aece2 2>/dev/null || git show --stat origin/main -1

echo ""
echo "=== Confirm our tier fix is still present in that commit's version of the file ==="
git show e45aece2:api/groq_client.py 2>/dev/null | grep -A 6 "MODEL_TIER_STACK = \["
