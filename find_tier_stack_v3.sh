#!/data/data/com.termux/files/usr/bin/bash
set -x

REPO=~/omega-agent-v2
cd "$REPO"

echo "=== Search whole repo for the exact error string from the failure ==="
grep -rln "model tiers exhausted" . --include="*.py" 2>/dev/null

echo ""
echo "=== Search whole repo for any other Groq model name strings (mixtral, gemma, kimi, qwen, gpt-oss, compound) ==="
grep -rln "mixtral\|gemma\|kimi\|qwen\|gpt-oss\|compound\|llama-3" . --include="*.py" 2>/dev/null | grep -v node_modules

echo ""
echo "=== Search for 'tiers' as a plural, likely the actual list variable name ==="
grep -rn "tiers\b" . --include="*.py" 2>/dev/null | grep -v node_modules
