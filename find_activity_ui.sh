#!/data/data/com.termux/files/usr/bin/bash
set -x

REPO=~/omega-agent-v2
cd "$REPO"

echo "=== Find where 'Activity' / 'View sandbox' / step rendering lives ==="
grep -rln "Activity\|View sandbox\|sandbox" src/ 2>/dev/null

echo ""
echo "=== Find where streaming steps/tool calls come in from the backend ==="
grep -rn "step\|tool_call\|EventSource\|job/stream" src/pages/Home.jsx | head -40
