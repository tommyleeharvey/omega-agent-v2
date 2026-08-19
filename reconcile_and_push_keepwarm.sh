#!/data/data/com.termux/files/usr/bin/bash
set -x

REPO=~/omega-agent-v2
cd "$REPO"

echo "=== Confirm which branch we're on and its upstream ==="
git branch -vv

echo ""
echo "=== Fetch latest from origin (tommyleeharvey) ==="
git fetch origin

echo ""
echo "=== Merge origin/main into local main (fast-forward if possible, safe merge otherwise) ==="
git merge origin/main --no-edit

echo ""
echo "=== Confirm keepwarm.yml survived the merge ==="
cat "$REPO/.github/workflows/keepwarm.yml"

echo ""
echo "=== Push explicitly to origin only (never cipherxsniper) ==="
git push origin main
