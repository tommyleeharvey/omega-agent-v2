#!/data/data/com.termux/files/usr/bin/bash
set -x

REPO=~/omega-agent-v2
cd "$REPO"

echo "=== useState declarations near the top of the component ==="
grep -n "useState" src/pages/Home.jsx | head -40

echo ""
echo "=== Context around the two onStep handlers ==="
sed -n '380,430p' src/pages/Home.jsx

echo ""
echo "=== Where ChatInput is rendered (to find the mobile-visible insertion point) ==="
grep -n "<ChatInput" src/pages/Home.jsx

echo ""
echo "=== Confirm the desktop-only wrapper we accidentally used ==="
grep -n 'hidden lg:block' src/pages/Home.jsx
