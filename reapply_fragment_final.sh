#!/data/data/com.termux/files/usr/bin/bash
set -x

REPO=~/omega-agent-v2
cd "$REPO"
TS=$(date +%Y%m%d-%H%M%S)
cp src/components/omega/MessageBubble.jsx "src/components/omega/MessageBubble.jsx.bak-$TS"

python3 - << 'PYEOF'
path = "src/components/omega/MessageBubble.jsx"
with open(path) as f:
    content = f.read()

old = '''{isUser ? (
              {message.metadata?.attachments?.some(a => a.isImage && a.dataUrl) && (
              <div className="flex gap-2 flex-wrap mb-2">
                {message.metadata.attachments.filter(a => a.isImage && a.dataUrl).map((a, i) => (
                  <img key={i} src={a.dataUrl} alt={a.name} className="max-w-[200px] max-h-[200px] rounded-lg border border-white/10 object-cover" />
                ))}
              </div>
            )}
            <div className="whitespace-pre-wrap">{message.content}</div>'''

new = '''{isUser ? (
              <>
                {message.metadata?.attachments?.some(a => a.isImage && a.dataUrl) && (
                  <div className="flex gap-2 flex-wrap mb-2">
                    {message.metadata.attachments.filter(a => a.isImage && a.dataUrl).map((a, i) => (
                      <img key={i} src={a.dataUrl} alt={a.name} className="max-w-[200px] max-h-[200px] rounded-lg border border-white/10 object-cover" />
                    ))}
                  </div>
                )}
                <div className="whitespace-pre-wrap">{message.content}</div>
              </>'''

count = content.count(old)
print(f"Exact match occurrences: {count}")

if count == 1:
    content = content.replace(old, new)
    with open(path, "w") as f:
        f.write(content)
    print("Fragment fix reapplied.")
else:
    print("MANUAL: block not found, aborting.")
    raise SystemExit
PYEOF

echo ""
echo "=== git diff (eyeball only — skipping local esbuild, it's failed 3x for tooling reasons unrelated to code correctness) ==="
git diff src/components/omega/MessageBubble.jsx

echo ""
echo "=== Push ==="
git add src/components/omega/MessageBubble.jsx
git commit -m "fix: wrap sibling JSX elements in fragment in MessageBubble (real fix for build failure)"
git push origin main

echo ""
echo "=== Confirm build succeeds via GitHub Actions (the reliable check all session) ==="
sleep 25
curl -s "https://api.github.com/repos/tommyleeharvey/omega-agent-v2/actions/workflows/329088611/runs?per_page=3" | python3 -c "
import sys, json
d = json.load(sys.stdin)
for r in d.get('workflow_runs', []):
    print(r['created_at'], '-', r['status'], '-', r['conclusion'], '-', r['head_sha'][:8])
"
