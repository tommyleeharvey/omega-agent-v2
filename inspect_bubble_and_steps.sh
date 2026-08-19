#!/data/data/com.termux/files/usr/bin/bash
set -x

REPO=~/omega-agent-v2
cd "$REPO"

echo "=== MessageBubble.jsx: find the copy button and its container ==="
grep -n "copy\|Copy\|clipboard" src/components/omega/MessageBubble.jsx

echo ""
echo "=== Show context around the copy button (adjust range once we see line numbers above) ==="
grep -n "className" src/components/omega/MessageBubble.jsx | head -30

echo ""
echo "=== Full MessageBubble.jsx (small enough to read in one shot?) ==="
wc -l src/components/omega/MessageBubble.jsx

echo ""
echo "=== WorkspacePanel.jsx: how the live steps/actions list currently renders ==="
grep -n "steps.map\|actions.map\|transcript.map\|key=" src/components/omega/WorkspacePanel.jsx

echo ""
echo "=== Any absolute/fixed positioning near the step rendering (possible real stacking bug) ==="
grep -n "absolute\|fixed\|z-\[" src/components/omega/WorkspacePanel.jsx

echo ""
echo "=== Current LiveActivityBar step list rendering (from what we shipped) ==="
grep -n "steps.map" src/components/omega/LiveActivityBar.jsx
