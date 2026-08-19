#!/data/data/com.termux/files/usr/bin/bash
set -x

REPO=~/omega-agent-v2
WORKFLOW_DIR="$REPO/.github/workflows"

mkdir -p "$WORKFLOW_DIR"

cat > "$WORKFLOW_DIR/keepwarm.yml" << 'YAML'
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
echo "=== Verify file ==="
cat "$WORKFLOW_DIR/keepwarm.yml"

echo ""
echo "=== Commit and push ==="
cd "$REPO" && git add .github/workflows/keepwarm.yml && git commit -m "Add scheduled keep-warm ping to prevent Render free-tier cold starts" && git push
