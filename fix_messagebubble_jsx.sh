#!/data/data/com.termux/files/usr/bin/bash
set -x

REPO=~/omega-agent-v2
cd "$REPO"
TS=$(date +%Y%m%d-%H%M%S)
cp src/components/omega/MessageBubble.jsx "src/components/omega/MessageBubble.jsx.bak-$TS"

echo "=== Show exact current broken block, lines 135-155 ==="
sed -n '135,155p' src/components/omega/MessageBubble.jsx

echo ""
echo "=== Rebuild the block cleanly with matched braces ==="
python3 - << 'PYEOF'
path = "src/components/omega/MessageBubble.jsx"
with open(path) as f:
    content = f.read()

# The broken block (from the failed build's own printed source lines 143-145)
broken_start = '{message.metadata?.attachments?.some(a => a.isImage && a.dataUrl) && ('
if broken_start not in content:
    print("MANUAL: broken_start marker not found — aborting to avoid corrupting further.")
    raise SystemExit

# Find the full broken region: from broken_start through the matching
# closing of that specific injected block, up to (but not including)
# the pre-existing <div className="whitespace-pre-wrap">{message.content}</div>
end_marker = '<div className="whitespace-pre-wrap">{message.content}</div>'
start_idx = content.find(broken_start)
end_idx = content.find(end_marker)

if start_idx == -1 or end_idx == -1 or end_idx < start_idx:
    print(f"MANUAL: could not locate a safe region. start_idx={start_idx} end_idx={end_idx}")
    raise SystemExit

region = content[start_idx:end_idx]
print("=== REGION BEING REPLACED ===")
print(region)
print("=== END REGION ===")

# Clean, correctly-closed replacement
clean_block = (
    '{message.metadata?.attachments?.some(a => a.isImage && a.dataUrl) && (\n'
    '              <div className="flex gap-2 flex-wrap mb-2">\n'
    '                {message.metadata.attachments.filter(a => a.isImage && a.dataUrl).map((a, i) => (\n'
    '                  <img key={i} src={a.dataUrl} alt={a.name} className="max-w-[200px] max-h-[200px] rounded-lg border border-white/10 object-cover" />\n'
    '                ))}\n'
    '              </div>\n'
    '            )}\n'
    '            '
)

content = content[:start_idx] + clean_block + content[end_idx:]

with open(path, "w") as f:
    f.write(content)
print("Replaced broken region with correctly-closed JSX block.")
PYEOF

echo ""
echo "=== Show the fixed region ==="
sed -n '135,155p' src/components/omega/MessageBubble.jsx

echo ""
echo "=== Local syntax check before pushing (esbuild, same tool CI uses) ==="
npx esbuild src/components/omega/MessageBubble.jsx --loader=jsx --bundle=false --outfile=/dev/null 2>&1 | tee /tmp/esbuild_check.txt
if grep -q "error" /tmp/esbuild_check.txt; then
  echo "STILL BROKEN — do not push. Restoring backup."
  cp "src/components/omega/MessageBubble.jsx.bak-$TS" src/components/omega/MessageBubble.jsx
  exit 1
fi
echo "Syntax OK locally."

echo ""
echo "=== Push the real fix ==="
git add src/components/omega/MessageBubble.jsx
git diff --cached src/components/omega/MessageBubble.jsx
git commit -m "fix: repair broken JSX in MessageBubble image-render block (unmatched brace from prior patch)"
git push origin main

echo ""
echo "=== Confirm this build succeeds ==="
sleep 25
curl -s "https://api.github.com/repos/tommyleeharvey/omega-agent-v2/actions/workflows/329088611/runs?per_page=3" | python3 -c "
import sys, json
d = json.load(sys.stdin)
for r in d.get('workflow_runs', []):
    print(r['created_at'], '-', r['status'], '-', r['conclusion'], '-', r['head_sha'][:8])
"
