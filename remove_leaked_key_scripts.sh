#!/data/data/com.termux/files/usr/bin/bash
set -x

REPO=~/omega-agent-v2
cd "$REPO"

echo "=== Remove the two scripts containing the hardcoded Gemini key from tracking ==="
git rm --cached apply_gemini_key.sh finalize_hybrid_brain.sh 2>/dev/null

echo ""
echo "=== Check if the key string exists anywhere else in the current working tree ==="
grep -rl "AQ.Ab8RN6KpA54ExIifVt3x3x03S8V0NxA0IVDlSEdB3ucRn8W07A" . 2>/dev/null | grep -v node_modules

echo ""
echo "=== Add these scripts + any .env to gitignore so auto-sync never re-adds them ==="
echo "apply_gemini_key.sh" >> .gitignore
echo "finalize_hybrid_brain.sh" >> .gitignore
echo "*.env" >> .gitignore

echo ""
echo "=== Commit removal + gitignore + the model fix together, then push ==="
git add .gitignore api/gemini_client.py
git commit -m "fix: gemini-2.5-flash retired for new accounts, switch to gemini-3.6-flash; remove scripts with hardcoded key from tracking"
git push origin main
