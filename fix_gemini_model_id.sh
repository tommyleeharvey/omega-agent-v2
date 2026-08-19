#!/data/data/com.termux/files/usr/bin/bash
set -x

REPO=~/omega-agent-v2
cd "$REPO"
TS=$(date +%Y%m%d-%H%M%S)
cp api/gemini_client.py "api/gemini_client.py.bak-$TS"

python3 - << 'PYEOF'
path = "api/gemini_client.py"
with open(path) as f:
    content = f.read()

old = 'GEMINI_MODEL = os.environ.get("GEMINI_MODEL", "gemini-2.5-flash")'
new = '''# gemini-2.5-flash was retired for new API accounts (404: "no longer
# available to new users"). gemini-3.6-flash is Google's current stable
# Flash model as of Aug 2026 - use GEMINI_MODEL env var to override without
# a redeploy if Google moves the goalposts again.
GEMINI_MODEL = os.environ.get("GEMINI_MODEL", "gemini-3.6-flash")'''

count = content.count(old)
print(f"Exact match occurrences: {count}")
if count == 1:
    content = content.replace(old, new)
    with open(path, "w") as f:
        f.write(content)
    print("Model ID updated to gemini-3.6-flash.")
else:
    print("MANUAL: block not found, aborting.")
    raise SystemExit
PYEOF

echo ""
echo "=== Show diff ==="
git diff api/gemini_client.py

echo ""
echo "=== Push ==="
git add api/gemini_client.py
git commit -m "fix: gemini-2.5-flash retired for new accounts, switch to gemini-3.6-flash"
git push origin main

echo ""
echo "=== Wait for Render auto-deploy, confirm live ==="
sleep 60
curl -s -H "Authorization: Bearer rnd_vv9FVHwsb9nQr5Giy527Gq5LTAwa" \
  "https://api.render.com/v1/services/srv-da20pelg1s2s73de3n70/deploys?limit=2" \
  | python3 -c "
import sys, json
d = json.load(sys.stdin)
for dep in d:
    dep = dep.get('deploy', dep)
    print(dep.get('commit', {}).get('id', '')[:8], '-', dep.get('status'))
"
curl -s https://omega-agent-backend-v2.onrender.com/api/health
