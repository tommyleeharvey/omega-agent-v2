#!/data/data/com.termux/files/usr/bin/bash
set -x

REPO=~/omega-agent-v2
cd "$REPO"
TS=$(date +%Y%m%d-%H%M%S)
cp src/components/omega/MessageBubble.jsx "src/components/omega/MessageBubble.jsx.bak-$TS"
cp src/pages/Home.jsx "src/pages/Home.jsx.bak-$TS"

echo "=== 1) Remove the duplicate Speak button block (keep only the first) ==="
python3 - << 'PYEOF'
path = "src/components/omega/MessageBubble.jsx"
with open(path) as f:
    content = f.read()

block = '''        {onSpeak && !isUser && (
          <button
            onClick={() => onSpeak(message.content)}
            className="flex items-center gap-1 text-[11px] text-white/25 hover:text-teal-400 transition-colors"
          >
            <Volume2 className="w-3 h-3" /> Speak
          </button>
        )}'''

count = content.count(block)
print(f"Speak block occurrences: {count}")

if count > 1:
    idx1 = content.find(block)
    idx2 = content.find(block, idx1 + len(block))
    content = content[:idx2] + content[idx2 + len(block):]
    with open(path, "w") as f:
        f.write(content)
    print(f"Removed duplicate block at offset {idx2}; kept the one at {idx1}.")
elif count == 1:
    print("Only one block present — no dupe to remove.")
else:
    print("MANUAL: exact block text not found — whitespace drifted, inspect by hand.")
PYEOF

echo ""
echo "=== 2) Remove the auto-speak call so voice only fires on manual tap ==="
python3 - << 'PYEOF'
path = "src/pages/Home.jsx"
with open(path) as f:
    content = f.read()

old = "setMessages((prev) => [...prev, assistantMsg]);\n    speakText(content);"
new = "setMessages((prev) => [...prev, assistantMsg]);"

if old in content:
    content = content.replace(old, new)
    with open(path, "w") as f:
        f.write(content)
    print("Removed auto speakText(content) call after assistant message lands.")
else:
    print("MANUAL: auto-speak line not found verbatim, check by hand.")
PYEOF

echo ""
echo "=== 3) DIAGNOSTIC ONLY — image upload not rendering in chat ==="
echo "--- How ChatInput collects/passes images ---"
grep -n "image\|Image\|attachment\|Attachment" src/components/omega/ChatInput.jsx

echo ""
echo "--- How the outgoing userMsg is built (search near line ~267) ---"
sed -n '240,275p' src/pages/Home.jsx

echo ""
echo "--- Does MessageBubble render any image/attachment field at all? ---"
grep -n "image\|Image\|attachment\|Attachment\|src=" src/components/omega/MessageBubble.jsx

echo ""
echo "=== 4) DIAGNOSTIC ONLY — 'Omega could not complete this job' errors ==="
RENDER_KEY=$(grep -oE "rnd_[A-Za-z0-9]{10,}" ~/omega-v2-pages-fix/.env | head -1)
SERVICE_ID="srv-da20pelg1s2s73de3n70"
echo "--- Backend health ---"
curl -s -o /dev/null -w "HTTP %{http_code}\n" https://omega-agent-backend-v2.onrender.com/api/health
echo "--- Last 5 deploys ---"
curl -s -H "Authorization: Bearer $RENDER_KEY" "https://api.render.com/v1/services/$SERVICE_ID/deploys?limit=5" | python3 -c "
import sys, json
d = json.load(sys.stdin)
for x in d:
    dep = x.get('deploy', x)
    print(dep.get('status'), '-', dep.get('commit', {}).get('id','')[:8])
"

echo ""
echo "=== Review diffs before pushing ==="
git diff src/components/omega/MessageBubble.jsx src/pages/Home.jsx

git add src/components/omega/MessageBubble.jsx src/pages/Home.jsx
git commit -m "fix: dedupe Speak button, remove auto-speak-on-response (voice now opt-in via tap)"
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
