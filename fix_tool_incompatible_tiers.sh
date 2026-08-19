#!/data/data/com.termux/files/usr/bin/bash
set -x

REPO=~/omega-agent-v2
cd "$REPO"
TS=$(date +%Y%m%d-%H%M%S)
cp api/groq_client.py "api/groq_client.py.bak-$TS"

python3 - << 'PYEOF'
path = "api/groq_client.py"
with open(path) as f:
    content = f.read()

old = '''MODEL_TIER_STACK = [
    "qwen/qwen3.6-27b",
    "openai/gpt-oss-120b",
    "openai/gpt-oss-20b",
    "groq/compound",
    "groq/compound-mini",
]'''

new = '''# groq/compound and groq/compound-mini removed: they don't support tool
# calling, and this agent uses tools on nearly every turn - keeping them in
# the stack meant every tool-using request that fell past gpt-oss-20b was
# guaranteed to fail regardless of retries. Now the last tier is gpt-oss-20b,
# which already gets a wait-and-retry on 429 via the sleep(wait_s) branch
# below instead of falling into tiers that can never serve the request.
MODEL_TIER_STACK = [
    "qwen/qwen3.6-27b",
    "openai/gpt-oss-120b",
    "openai/gpt-oss-20b",
]'''

count = content.count(old)
print(f"Exact match occurrences: {count}")
if count == 1:
    content = content.replace(old, new)
    with open(path, "w") as f:
        f.write(content)
    print("Tier stack fixed: tool-incompatible models removed.")
else:
    print("MANUAL: block not found, aborting.")
    raise SystemExit
PYEOF

echo ""
echo "=== Show diff ==="
git diff api/groq_client.py

echo ""
echo "=== Push ==="
git add api/groq_client.py
git commit -m "fix: remove groq/compound and compound-mini from tier stack (no tool-calling support, guaranteed failures on tool-using requests)"
git push origin main
