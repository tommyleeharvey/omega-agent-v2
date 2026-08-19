#!/data/data/com.termux/files/usr/bin/bash
set -x

REPO=~/omega-agent-v2
cd "$REPO"

echo "=== Where normalizedAttachments is defined/built ==="
grep -n "normalizedAttachments" src/pages/Home.jsx

echo ""
echo "=== Full context around that definition ==="
LINE=$(grep -n "const normalizedAttachments" src/pages/Home.jsx | head -1 | cut -d: -f1)
if [ -n "$LINE" ]; then
  sed -n "$((LINE-5)),$((LINE+25))p" src/pages/Home.jsx
else
  echo "MANUAL: normalizedAttachments assignment not found by that exact pattern — showing handleSend top instead"
  grep -n "const handleSend" src/pages/Home.jsx
fi

echo ""
echo "=== Full ChatInput handleFiles function (how files become attachments) ==="
grep -n "handleFiles" src/components/omega/ChatInput.jsx
sed -n '38,60p' src/components/omega/ChatInput.jsx

echo ""
echo "=== Confirm blob revoke timing relative to message save ==="
grep -n "revokeObjectURL" src/components/omega/ChatInput.jsx
