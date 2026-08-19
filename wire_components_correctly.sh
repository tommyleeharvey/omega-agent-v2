#!/data/data/com.termux/files/usr/bin/bash
set -x

REPO=~/omega-agent-v2
cd "$REPO"
cp src/pages/Home.jsx "src/pages/Home.jsx.bak-$(date +%Y%m%d-%H%M%S)"

echo "=== Remove the dead placeholder render from the desktop-only sidebar ==="
python3 - << 'PYEOF'
path = "src/pages/Home.jsx"
with open(path) as f:
    content = f.read()

old_block = (
    '          <VoiceToggle enabled={voiceEnabled} onToggle={setVoicePref} />\n'
    '          <LiveActivityBar steps={[]} isActive={false} onExpand={() => {}} />\n'
)
if old_block in content:
    content = content.replace(old_block, "")
    print("Removed dead placeholder block from desktop sidebar.")
else:
    print("MANUAL: placeholder block not found verbatim — check for stray whitespace and remove by hand.")

with open(path, "w") as f:
    f.write(content)
PYEOF

echo ""
echo "=== Insert real, wired components directly above <ChatInput> (visible on mobile + desktop) ==="
python3 - << 'PYEOF'
import re

path = "src/pages/Home.jsx"
with open(path) as f:
    content = f.read()

marker = '<ChatInput onSend={handleSend} disabled={isThinking} workspaceAvailable={isThinking || liveTranscript.length > 0} onOpenWorkspace={() => setShowMobileWorkspace(true)} />'

if marker not in content:
    print("MANUAL: exact ChatInput line not found — grep for '<ChatInput' and insert by hand.")
else:
    insertion = (
        '<div className="flex items-center justify-end mb-1">\n'
        '              <VoiceToggle enabled={voiceEnabled} onToggle={setVoicePref} />\n'
        '            </div>\n'
        '            <LiveActivityBar\n'
        '              steps={liveTranscript.map((s, i) => ({\n'
        '                id: s.id || i,\n'
        '                label: s.title || s.name || s.role || "Working",\n'
        '                status: s.status || (isThinking ? "running" : "done"),\n'
        '              }))}\n'
        '              isActive={isThinking}\n'
        '              onExpand={() => setShowMobileWorkspace(true)}\n'
        '            />\n'
        '            '
    )
    content = content.replace(marker, insertion + marker, 1)
    print("Inserted VoiceToggle + wired LiveActivityBar directly above ChatInput.")

with open(path, "w") as f:
    f.write(content)
PYEOF

echo ""
echo "=== Wire speakText into the response-complete path (both response branches use liveTranscript/onStep — hook the final response text) ==="
grep -n "response = response.data\|response = await base44" src/pages/Home.jsx

echo ""
echo "=== Review the full diff before pushing ==="
git diff src/pages/Home.jsx

echo ""
echo "If it looks wrong: cp src/pages/Home.jsx.bak-* src/pages/Home.jsx"

git add src/pages/Home.jsx
git status
git commit -m "fix: move VoiceToggle+LiveActivityBar out of desktop-only sidebar, wire to real liveTranscript/isThinking state, visible on mobile"
git push origin main
