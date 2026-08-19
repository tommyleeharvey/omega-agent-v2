#!/data/data/com.termux/files/usr/bin/bash
set -x

REPO=~/omega-agent-v2
cd "$REPO"
cp src/components/omega/MessageBubble.jsx "src/components/omega/MessageBubble.jsx.bak-$(date +%Y%m%d-%H%M%S)"
cp src/pages/Home.jsx "src/pages/Home.jsx.bak-$(date +%Y%m%d-%H%M%S)"
cp src/hooks/useVoice.js "src/hooks/useVoice.js.bak-$(date +%Y%m%d-%H%M%S)"

echo "=== Check how many times the Speak button block exists in MessageBubble.jsx ==="
grep -c "onSpeak(message.content)" src/components/omega/MessageBubble.jsx

echo ""
echo "=== 1) Dedupe: keep only the FIRST Speak button block, remove any extra ==="
python3 - << 'PYEOF'
import re
path = "src/components/omega/MessageBubble.jsx"
with open(path) as f:
    content = f.read()

block_pattern = re.compile(
    r'\s*\{onSpeak && !isUser && \(\s*'
    r'<button\s*\n?\s*onClick=\{\(\) => onSpeak\(message\.content\)\}[^}]*\}[^)]*\)\}',
    re.DOTALL
)
matches = list(block_pattern.finditer(content))
print(f"Found {len(matches)} Speak block(s)")

if len(matches) > 1:
    # remove every match after the first
    for m in reversed(matches[1:]):
        content = content[:m.start()] + content[m.end():]
    with open(path, "w") as f:
        f.write(content)
    print(f"Removed {len(matches)-1} duplicate block(s), kept the first.")
elif len(matches) == 1:
    print("Only one block found — no dedupe needed (issue may be elsewhere, check onSpeak call site).")
else:
    print("MANUAL: pattern didn't match — grep output above shows raw count, inspect by hand.")
PYEOF

echo ""
echo "=== 2) Remove the global VoiceToggle (import + render) from Home.jsx — per-message Speak buttons are enough ==="
python3 - << 'PYEOF'
import re
path = "src/pages/Home.jsx"
with open(path) as f:
    content = f.read()

content = content.replace('import VoiceToggle from "@/components/omega/VoiceToggle";\n', "")

content = re.sub(
    r'\s*<div className="flex items-center justify-end mb-1">\s*<VoiceToggle enabled=\{voiceEnabled\} onToggle=\{setVoicePref\} />\s*</div>\n?',
    "\n",
    content
)

content = content.replace(
    "const { voiceEnabled, setVoicePref, speakText } = useVoice();",
    "const { speakText } = useVoice();"
)

with open(path, "w") as f:
    f.write(content)
print("VoiceToggle removed from Home.jsx; only speakText retained from useVoice().")
PYEOF

echo ""
echo "=== 3) Rewrite useVoice.js to use the browser's native speech synthesis instead of the broken /api/tts backend ==="
cat > src/hooks/useVoice.js << 'JSEOF'
import { useCallback, useRef } from "react";

/**
 * Uses the browser's built-in speechSynthesis API. No backend call, no
 * model to host — works immediately on any device with a browser voice
 * available. (The earlier /api/tts + Chatterbox path is not in use:
 * Chatterbox was removed from the backend because it OOM'd Render's
 * free-tier build. This is the working replacement, not a cloned voice.)
 */
export function useVoice() {
  const utteranceRef = useRef(null);

  const speakText = useCallback((text) => {
    if (!text || !("speechSynthesis" in window)) return;
    window.speechSynthesis.cancel(); // stop any prior utterance first
    const utterance = new SpeechSynthesisUtterance(text);
    utterance.rate = 1;
    utterance.pitch = 1;
    utteranceRef.current = utterance;
    window.speechSynthesis.speak(utterance);
  }, []);

  return { speakText };
}
JSEOF

node -e "require('fs').readFileSync('src/hooks/useVoice.js','utf8')" && echo "useVoice.js OK"

echo ""
echo "=== Delete the now-unused VoiceToggle component and dead /api/tts backend code (frontend cleanup only, backend untouched) ==="
rm -f src/components/omega/VoiceToggle.jsx
grep -rn "VoiceToggle" src/ || echo "No remaining references to VoiceToggle — clean."

echo ""
echo "=== Review full diff before pushing ==="
git diff src/components/omega/MessageBubble.jsx src/pages/Home.jsx src/hooks/useVoice.js
git status

echo ""
echo "If anything looks wrong: cp src/pages/Home.jsx.bak-* src/pages/Home.jsx (etc for the other two)"

git add -A src/components/omega/MessageBubble.jsx src/pages/Home.jsx src/hooks/useVoice.js src/components/omega/VoiceToggle.jsx
git status
git commit -m "fix: remove duplicate Speak button and global voice toggle; switch voice to browser speechSynthesis (Chatterbox backend was never functional post-OOM-fix)"
git push origin main

echo ""
echo "=== Confirm build succeeds ==="
sleep 20
curl -s "https://api.github.com/repos/tommyleeharvey/omega-agent-v2/actions/workflows/329088611/runs?per_page=3" | python3 -c "
import sys, json
d = json.load(sys.stdin)
for r in d.get('workflow_runs', []):
    print(r['created_at'], '-', r['status'], '-', r['conclusion'], '-', r['head_sha'][:8])
"
