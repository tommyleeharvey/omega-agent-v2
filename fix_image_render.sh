#!/data/data/com.termux/files/usr/bin/bash
set -x

REPO=~/omega-agent-v2
cd "$REPO"
TS=$(date +%Y%m%d-%H%M%S)
cp src/pages/Home.jsx "src/pages/Home.jsx.bak-$TS"
cp src/components/omega/MessageBubble.jsx "src/components/omega/MessageBubble.jsx.bak-$TS"

echo "=== 1) Stop stripping dataUrl/isImage when saving message metadata ==="
python3 - << 'PYEOF'
path = "src/pages/Home.jsx"
with open(path) as f:
    content = f.read()

old = "attachments: normalizedAttachments.map(({ name, type, size }) => ({ name, type, size })),"
new = "attachments: normalizedAttachments.map(({ name, type, size, isImage, dataUrl }) => ({ name, type, size, isImage, dataUrl: isImage ? dataUrl : null })),"

count = content.count(old)
print(f"Occurrences of stripped attachment mapper: {count}")
if count > 0:
    content = content.replace(old, new)
    with open(path, "w") as f:
        f.write(content)
    print(f"Replaced {count} occurrence(s) — dataUrl now persisted for images.")
else:
    print("MANUAL: mapper line not found verbatim, check by hand.")
PYEOF

echo ""
echo "=== 2) Render attached images in MessageBubble, above the text content ==="
python3 - << 'PYEOF'
path = "src/components/omega/MessageBubble.jsx"
with open(path) as f:
    content = f.read()

marker = '<div className="whitespace-pre-wrap">{message.content}</div>'
count = content.count(marker)
print(f"Content div occurrences: {count}")

insertion = '''{message.metadata?.attachments?.some(a => a.isImage && a.dataUrl) && (
              <div className="flex gap-2 flex-wrap mb-2">
                {message.metadata.attachments.filter(a => a.isImage && a.dataUrl).map((a, i) => (
                  <img key={i} src={a.dataUrl} alt={a.name} className="max-w-[200px] max-h-[200px] rounded-lg border border-white/10 object-cover" />
                ))}
              </div>
            )}
            '''

if count == 1 and "attachments?.some" not in content:
    content = content.replace(marker, insertion + marker, 1)
    with open(path, "w") as f:
        f.write(content)
    print("Inserted image render block above message content.")
elif "attachments?.some" in content:
    print("Already inserted — skipping.")
else:
    print("MANUAL: content div marker not found or not unique, check by hand.")
PYEOF

echo ""
echo "=== Review diffs before pushing ==="
git diff src/pages/Home.jsx src/components/omega/MessageBubble.jsx

git add src/pages/Home.jsx src/components/omega/MessageBubble.jsx
git commit -m "fix: persist image dataUrl in message metadata and render attached images in MessageBubble"
git push origin main

echo ""
echo "=== Confirm build ==="
sleep 20
curl -s "https://api.github.com/repos/tommyleeharvey/omega-agent-v2/actions/workflows/329088611/runs?per_page=3" | python3 -c "
import sys, json
d = json.load(sys.stdin)
for r in d.get('workflow_runs', []):
    print(r['created_at'], '-', r['status'], '-', r['conclusion'], '-', r['head_sha'][:8])
"
