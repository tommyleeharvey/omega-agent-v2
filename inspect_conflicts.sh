#!/data/data/com.termux/files/usr/bin/bash
set -x

REPO=~/omega-agent-v2
cd "$REPO"

echo "=== Files in conflict ==="
git diff --name-only --diff-filter=U

echo ""
echo "=== agent_loop.py conflict: check if the break-gated-behind-on_step bug is still present in EITHER side ==="
grep -n "on_step\|break" agent/agent_loop.py | grep -A2 -B2 "<<<<<<<\|=======\|>>>>>>>"

echo ""
echo "=== Show conflict markers with context in agent_loop.py ==="
grep -n "<<<<<<<\|=======\|>>>>>>>" agent/agent_loop.py

echo ""
echo "=== .gitignore conflict (usually trivial to resolve) ==="
cat .gitignore

echo ""
echo "=== WorkspacePanel.jsx conflict markers ==="
grep -n "<<<<<<<\|=======\|>>>>>>>" src/components/omega/WorkspacePanel.jsx

echo ""
echo "=== Home.jsx conflict markers ==="
grep -n "<<<<<<<\|=======\|>>>>>>>" src/pages/Home.jsx
