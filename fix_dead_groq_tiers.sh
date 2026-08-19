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
    "llama-3.3-70b-versatile",
    "openai/gpt-oss-120b",
    "openai/gpt-oss-20b",
    "llama-3.1-8b-instant",
]'''

new = '''MODEL_TIER_STACK = [
    "qwen/qwen3.6-27b",
    "openai/gpt-oss-120b",
    "openai/gpt-oss-20b",
    "groq/compound",
    "groq/compound-mini",
]'''

count = content.count(old)
print(f"Exact match occurrences: {count}")
if count == 1:
    content = content.replace(old, new)
    with open(path, "w") as f:
        f.write(content)
    print("Tier stack updated: dead llama models replaced.")
else:
    print("MANUAL: block not found, aborting.")
    raise SystemExit
PYEOF

echo ""
echo "=== Also fix stale TPM limit key (still references dead llama-3.1-8b-instant) ==="
python3 - << 'PYEOF'
path = "api/groq_client.py"
with open(path) as f:
    content = f.read()

old = '''MODEL_TPM_LIMITS = {
    "llama-3.1-8b-instant": 6000,
}'''
new = '''MODEL_TPM_LIMITS = {
    "openai/gpt-oss-20b": 6000,
}'''
count = content.count(old)
print(f"TPM block match occurrences: {count}")
if count == 1:
    content = content.replace(old, new)
    with open(path, "w") as f:
        f.write(content)
    print("TPM limit key updated.")
else:
    print("MANUAL: TPM block not found, leaving as-is.")
PYEOF

echo ""
echo "=== Show diff ==="
git diff api/groq_client.py

echo ""
echo "=== Push ==="
git add api/groq_client.py
git commit -m "fix: remove dead Groq models (llama-3.1-8b-instant, llama-3.3-70b-versatile) from tier stack"
git push origin main
