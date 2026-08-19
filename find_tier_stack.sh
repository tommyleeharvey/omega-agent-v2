#!/data/data/com.termux/files/usr/bin/bash
set -x

REPO=~/omega-agent-v2
cd "$REPO"

echo "=== Search wider for the actual 5-tier fallback list (not just the two dead model names) ==="
grep -rln "tier\|TIER\|fallback\|FALLBACK" agent/ 2>/dev/null

echo ""
echo "=== Show llm_client.py in full, this is where the default model + likely tier logic lives ==="
cat -n agent/core/llm_client.py
