#!/data/data/com.termux/files/usr/bin/bash
set -x

REPO=~/omega-agent-v2
cd "$REPO"

echo "=== Confirm the live deployed commit matches local ==="
git log --oneline -1
curl -s "https://api.github.com/repos/tommyleeharvey/omega-agent-v2/actions/workflows/329088611/runs?per_page=1" | python3 -c "
import sys, json
d = json.load(sys.stdin)
r = d['workflow_runs'][0]
print(r['created_at'], '-', r['status'], '-', r['conclusion'], '-', r['head_sha'][:8])
"

echo ""
echo "=== Confirm exactly one Speak button and it calls speakText correctly ==="
grep -n "onSpeak\|speakText\|Volume2" src/components/omega/MessageBubble.jsx
grep -n "onSpeak\|speakText" src/pages/Home.jsx

echo ""
echo "=== Confirm useVoice.js current content ==="
cat src/hooks/useVoice.js
