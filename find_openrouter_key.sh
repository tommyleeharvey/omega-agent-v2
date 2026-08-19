#!/data/data/com.termux/files/usr/bin/bash
set -x
echo "=== Look for the existing OpenRouter key from prior sessions ==="
grep -oE "OPENROUTER_API_KEY=.*" ~/.omega/nexus/.env 2>/dev/null
grep -oE "OPENROUTER_API_KEY=.*" ~/.omega/.env 2>/dev/null
grep -rl "sk-or-" ~/.omega/ ~/omega-agent-v2/ 2>/dev/null | grep -v node_modules
