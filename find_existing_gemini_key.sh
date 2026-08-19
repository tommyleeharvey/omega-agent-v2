#!/data/data/com.termux/files/usr/bin/bash
set -x
cd ~/omega-agent-v2

echo "=== 1) check apply_gemini_key.sh - it may show where it expects the key from ==="
cat apply_gemini_key.sh 2>/dev/null

echo ""
echo "=== 2) search common places a key might be sitting ==="
grep -rl "GEMINI_API_KEY\|AIza" ~/.bashrc ~/.profile ~/.zshrc ~/.env 2>/dev/null
find ~ -maxdepth 2 -iname "*.env*" 2>/dev/null

echo ""
echo "=== 3) shell history for any gemini key mentions (won't print the key itself, just line numbers/context markers) ==="
grep -n "GEMINI" ~/.bash_history 2>/dev/null | wc -l

echo ""
echo "=== 4) any other env files inside the repo besides .env ==="
find . -maxdepth 2 -iname "*.env*" 2>/dev/null | grep -v node_modules
