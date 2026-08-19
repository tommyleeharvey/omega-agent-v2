#!/data/data/com.termux/files/usr/bin/bash
set -x

REPO=~/omega-agent-v2
cd "$REPO"

echo "=== 1) All on_step(...) call sites in agent_loop.py - what fields does a step actually carry ==="
grep -n "on_step(" agent/agent_loop.py

echo ""
echo "=== 2) Show 15 lines around each on_step call ==="
grep -n "on_step(" agent/agent_loop.py | cut -d: -f1 | while read -r ln; do
  echo "--- around line $ln ---"
  sed -n "$((ln-8)),$((ln+8))p" agent/agent_loop.py
done

echo ""
echo "=== 3) WorkspacePanel.jsx - the tab layout (proofchain/actions/browser/terminal/files) ==="
cat -n src/components/omega/WorkspacePanel.jsx

echo ""
echo "=== 4) SandboxPanel.jsx - browser rendering ==="
cat -n src/components/omega/SandboxPanel.jsx
