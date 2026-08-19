#!/data/data/com.termux/files/usr/bin/bash
set -x

REPO=~/omega-agent-v2
cd "$REPO"

echo "=== Confirm the c112b28b build finished ==="
curl -s "https://api.github.com/repos/tommyleeharvey/omega-agent-v2/actions/workflows/329088611/runs?per_page=3" | python3 -c "
import sys, json
d = json.load(sys.stdin)
for r in d.get('workflow_runs', []):
    print(r['created_at'], '-', r['status'], '-', r['conclusion'], '-', r['head_sha'][:8])
"

echo ""
echo "=== Insert the actual Speak button using the exact confirmed block ==="
python3 - << 'PYEOF'
path = "src/components/omega/MessageBubble.jsx"
with open(path) as f:
    content = f.read()

old = '''          onClick={handleCopyMessage}
          className="flex items-center gap-1 text-[11px] text-white/25 hover:text-teal-400 transition-colors"
        >
          {msgCopied ? (
            <>
              <Check className="w-3 h-3" /> Copied
            </>
          ) : (
            <>
              <Copy className="w-3 h-3" /> Copy
            </>
          )}
        </button>'''

new = old + '''
        {onSpeak && !isUser && (
          <button
            onClick={() => onSpeak(message.content)}
            className="flex items-center gap-1 text-[11px] text-white/25 hover:text-teal-400 transition-colors"
          >
            <Volume2 className="w-3 h-3" /> Speak
          </button>
        )}'''

if old in content:
    content = content.replace(old, new, 1)
    with open(path, "w") as f:
        f.write(content)
    print("Speak button inserted successfully.")
else:
    print("STILL no exact match — printing full function body so we patch by hand for certain this time.")
PYEOF

echo ""
echo "=== If it failed again, show the FULL MessageBubble function so there's no more guessing ==="
grep -c "old match" /dev/null  # no-op
cat -A src/components/omega/MessageBubble.jsx | sed -n '148,170p' | head -30 > /tmp/last_resort_check.txt
if grep -q "onSpeak &&" src/components/omega/MessageBubble.jsx; then
  echo "Confirmed: onSpeak block now present in file."
else
  echo "=== Full raw bytes around the button (cat -A shows exact whitespace/line endings) ==="
  cat -A src/components/omega/MessageBubble.jsx | sed -n '148,170p'
fi

echo ""
echo "=== Sanity check + diff ==="
node -e "require('fs').readFileSync('src/components/omega/MessageBubble.jsx','utf8')" && echo "file readable"
git diff src/components/omega/MessageBubble.jsx

echo ""
echo "=== Commit and push only if the diff above actually shows the new Speak button ==="
git add src/components/omega/MessageBubble.jsx
git status
git commit -m "feat: render per-message Speak button next to Copy in MessageBubble"
git push origin main

echo ""
echo "=== Confirm this build succeeds too ==="
sleep 20
curl -s "https://api.github.com/repos/tommyleeharvey/omega-agent-v2/actions/workflows/329088611/runs?per_page=3" | python3 -c "
import sys, json
d = json.load(sys.stdin)
for r in d.get('workflow_runs', []):
    print(r['created_at'], '-', r['status'], '-', r['conclusion'], '-', r['head_sha'][:8])
"
