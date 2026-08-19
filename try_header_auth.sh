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

old = '''    url = GEMINI_API_URL.format(model=os.environ.get("GEMINI_MODEL", GEMINI_MODEL))
    response = requests.post(url, params={"key": key}, json=payload, timeout=60)'''

new = '''    # AQ.-prefix keys (Google's newer key format, rolling out through 2026)
    # are unreliable via the ?key= query param and sometimes need the
    # x-goog-api-key header instead - same key, different transport.
    url = GEMINI_API_URL.format(model=os.environ.get("GEMINI_MODEL", GEMINI_MODEL))
    response = requests.post(
        url,
        headers={"x-goog-api-key": key, "Content-Type": "application/json"},
        json=payload,
        timeout=60,
    )'''

count = content.count(old)
print(f"Exact match occurrences: {count}")
if count == 1:
    content = content.replace(old, new)
    with open(path, "w") as f:
        f.write(content)
    print("Switched to x-goog-api-key header auth.")
else:
    print("MANUAL: block not found, aborting.")
    raise SystemExit
PYEOF

echo ""
echo "=== Diff ==="
git diff api/gemini_client.py

echo ""
echo "=== Push ==="
git add api/gemini_client.py
git commit -m "fix: use x-goog-api-key header instead of ?key= query param for Gemini auth (AQ.-format keys unreliable via query param)"
git push origin main

echo ""
echo "=== Wait for deploy ==="
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
