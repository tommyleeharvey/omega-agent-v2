#!/data/data/com.termux/files/usr/bin/bash
set -x

REPO=~/omega-agent-v2
cd "$REPO"

echo "=== 1) How Home.jsx derives step labels from onStep events ==="
sed -n '380,440p' src/pages/Home.jsx

echo ""
echo "=== 2) What the backend actually sends per step (tool name, args, etc) ==="
grep -n "onStep\|yield.*step\|step_type\|def.*step" agent/agent_loop.py | head -30

echo ""
echo "=== 3) Find the Agent Actions panel (proofchain/actions/browser/terminal/files tabs) ==="
grep -rln "proofchain\|Proofchain\|Terminal\|Browser" src/components/omega/ 2>/dev/null | grep -v ".bak"

echo ""
echo "=== 4) Show that panel's tab layout ==="
grep -rln "proofchain\|Proofchain" src/components/omega/*.jsx 2>/dev/null | grep -v ".bak" | head -1 | xargs cat -n
