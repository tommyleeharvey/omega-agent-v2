#!/data/data/com.termux/files/usr/bin/bash
set -x

REPO=~/omega-agent-v2
cd "$REPO"

echo "=== 1) URGENT: fix the broken MessageBubble line in Home.jsx ==="
python3 - << 'PYEOF'
path = "src/pages/Home.jsx"
with open(path) as f:
    content = f.read()

broken = '<MessageBubble key={msg.id} message={msg} onOpenWorkspace={() = onSpeak={speakText} /> setShowMobileWorkspace(true)} />'
fixed = '<MessageBubble key={msg.id} message={msg} onOpenWorkspace={() => setShowMobileWorkspace(true)} onSpeak={speakText} />'

if broken in content:
    content = content.replace(broken, fixed)
    with open(path, "w") as f:
        f.write(content)
    print("FIXED: restored valid JSX with onSpeak correctly appended.")
else:
    print("MANUAL: exact broken string not found — grep for 'onOpenWorkspace={() =' and fix by hand immediately.")
PYEOF

grep -n "<MessageBubble" src/pages/Home.jsx

echo ""
echo "=== 2) Verify no other broken JSX slipped through — basic paren/brace sanity via node ==="
node -e "
const babel = require('@babel/core');
try {
  babel.transformFileSync('src/pages/Home.jsx', { presets: ['@babel/preset-react'] });
  console.log('Home.jsx parses OK');
} catch (e) {
  console.log('PARSE ERROR:', e.message);
}
" 2>&1 || echo "babel not available locally — rely on the Pages Action build result instead"

echo ""
echo "=== 3) Finish MessageBubble.jsx: apply the actual Speak button (exact text confirmed from your paste) ==="
python3 - << 'PYEOF'
path = "src/components/omega/MessageBubble.jsx"
with open(path) as f:
    content = f.read()

old = '''<button onClick={handleCopyMessage} className="flex items-center gap-1 text-[11px] text-white/25 hover:text-teal-400 transition-colors">
            {copied ? (<><Check className="w-3 h-3" /> Copied</>) : (<><Copy className="w-3 h-3" /> Copy</>)}
          </button>'''

# Try exact match first
if old in content:
    new = old + '''
          {onSpeak && !isUser && (
            <button onClick={() => onSpeak(message.content)} className="flex items-center gap-1 text-[11px] text-white/25 hover:text-teal-400 transition-colors">
              <Volume2 className="w-3 h-3" /> Speak
            </button>
          )}'''
    content = content.replace(old, new, 1)
    with open(path, "w") as f:
        f.write(content)
    print("Inserted Speak button after Copy button (exact match).")
else:
    print("MANUAL: exact whitespace didn't match — will show you the real block below to patch by hand.")
PYEOF

echo ""
echo "=== Show the actual current handleCopyMessage button block (to hand-patch if step 3 said MANUAL) ==="
grep -n "handleCopyMessage" src/components/omega/MessageBubble.jsx
sed -n '148,168p' src/components/omega/MessageBubble.jsx

echo ""
echo "=== Full diff review before pushing ==="
git diff src/pages/Home.jsx src/components/omega/MessageBubble.jsx

echo ""
echo "=== Commit and push the urgent fix + completed feature together ==="
git add src/pages/Home.jsx src/components/omega/MessageBubble.jsx
git status
git commit -m "fix: URGENT - repair broken JSX from bad regex insertion in previous commit; complete per-message Speak button"
git push origin main

echo ""
echo "=== Confirm the Pages build actually succeeds this time ==="
sleep 20
curl -s "https://api.github.com/repos/tommyleeharvey/omega-agent-v2/actions/workflows/329088611/runs?per_page=3" | python3 -c "
import sys, json
d = json.load(sys.stdin)
for r in d.get('workflow_runs', []):
    print(r['created_at'], '-', r['status'], '-', r['conclusion'], '-', r['head_sha'][:8])
"
