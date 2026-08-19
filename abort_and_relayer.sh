#!/data/data/com.termux/files/usr/bin/bash
set -x

REPO=~/omega-agent-v2
cd "$REPO"

echo "=== Abort the messy merge, return to clean state ==="
git merge --abort

echo ""
echo "=== Reset local main to exactly match origin/main (the real, current source of truth) ==="
git checkout main
git reset --hard origin/main

echo ""
echo "=== Confirm we're now clean and matching origin ==="
git status
git log --oneline -3

echo ""
echo "=== Re-add just the keep-warm workflow on top of the real current state ==="
mkdir -p "$REPO/.github/workflows"
cat > "$REPO/.github/workflows/keepwarm.yml" << 'YAML'
name: keep-backend-warm

on:
  schedule:
    - cron: '*/10 * * * *'
  workflow_dispatch:

jobs:
  ping:
    runs-on: ubuntu-latest
    steps:
      - name: Ping backend health endpoint
        run: |
          curl -sf --max-time 60 https://omega-agent-backend-v2.onrender.com/api/health || echo "Ping failed (backend may have been cold - this is expected occasionally)"
YAML

echo ""
echo "=== Confirm agent_loop.py's break-inside-on_step area (sanity check the bug isn't back) ==="
grep -n "on_step\|break" agent/agent_loop.py | head -20

echo ""
echo "=== Commit and push just this one new file ==="
git add .github/workflows/keepwarm.yml
git commit -m "Add scheduled keep-warm ping to prevent Render free-tier cold starts"
git push origin main
