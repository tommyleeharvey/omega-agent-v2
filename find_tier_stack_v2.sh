#!/data/data/com.termux/files/usr/bin/bash
set -x

REPO=~/omega-agent-v2
cd "$REPO"

echo "=== Grep omega_brain.py and reasoning_v2.py for tier/model definitions ==="
grep -n "tier\|TIER\|fallback\|FALLBACK\|model" agent/core/omega_brain.py

echo ""
echo "=== Same for reasoning_v2.py ==="
grep -n "tier\|TIER\|fallback\|FALLBACK\|model" agent/core/reasoning_v2.py
