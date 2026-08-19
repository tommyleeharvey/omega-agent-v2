#!/data/data/com.termux/files/usr/bin/bash
set -x
echo "=== Check if you already have an Anthropic key saved locally somewhere ==="
grep -oE "ANTHROPIC_API_KEY=.*" ~/omega-agent-v2/.env 2>/dev/null
grep -oE "ANTHROPIC_API_KEY=.*" ~/.omega/.env 2>/dev/null
grep -rlE "sk-ant-" ~/.omega/ ~/omega-agent-v2/ 2>/dev/null | grep -v node_modules
