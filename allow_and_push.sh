#!/data/data/com.termux/files/usr/bin/bash
set -x
cd ~/omega-agent-v2
git rm --cached build_openrouter_tier.sh 2>/dev/null
echo "build_openrouter_tier.sh" >> .gitignore
git add .gitignore
git commit -m "chore: stop tracking script with hardcoded OpenRouter key"
git push origin main
