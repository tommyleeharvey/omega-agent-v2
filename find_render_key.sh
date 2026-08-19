#!/data/data/com.termux/files/usr/bin/bash
set -x

echo "=== Searching entire home directory (excluding node_modules/.git) for rnd_ keys ==="
grep -rlE "rnd_[A-Za-z0-9]{10,}" ~/ 2>/dev/null | grep -v node_modules | grep -v "/\.git/" | grep -v "/site-packages/"

echo ""
echo "=== Also check common shell config / env files explicitly ==="
for f in ~/.bashrc ~/.bash_profile ~/.profile ~/.zshrc ~/.termux/termux.properties ~/omega-agent-v2/.env ~/omega-agent-v2/.env.local ~/omega-agent-v2/render.yaml ~/omega_workspace/*/.env ~/omega_workspace/*/*.env; do
  if [ -f "$f" ]; then
    MATCH=$(grep -oE "rnd_[A-Za-z0-9]{10,}" "$f" 2>/dev/null)
    if [ -n "$MATCH" ]; then
      echo "FOUND in $f"
    fi
  fi
done

echo ""
echo "=== Also check any files literally named like a key/credentials store ==="
find ~/ -maxdepth 4 -iname "*render*" -not -path "*/node_modules/*" -not -path "*/.git/*" 2>/dev/null

echo ""
echo "=== If still nothing, grep more loosely for 'RENDER' env var assignments anywhere ==="
grep -rlE "RENDER_API_KEY" ~/ 2>/dev/null | grep -v node_modules | grep -v "/\.git/"
