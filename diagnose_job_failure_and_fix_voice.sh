#!/data/data/com.termux/files/usr/bin/bash
set -x

echo "=== 1) Find where 'could not complete this job' comes from (frontend fallback vs backend) ==="
cd ~/omega-agent-v2
grep -rn "could not complete this job" src/ 2>/dev/null
grep -rn "timeout" src/hooks/ src/pages/Home.jsx 2>/dev/null | grep -i "fetch\|axios\|AbortController\|setTimeout"

echo ""
echo "=== 2) Pull recent Render backend logs around the failure, filtered for errors/tracebacks ==="
curl -s -H "Authorization: Bearer rnd_vv9FVHwsb9nQr5Giy527Gq5LTAwa" \
  "https://api.render.com/v1/logs?ownerId=tea-cumojslumphs738ld8fg&resource=srv-da20pelg1s2s73de3n70&limit=100&text=Traceback" \
  | python3 -m json.tool

curl -s -H "Authorization: Bearer rnd_vv9FVHwsb9nQr5Giy527Gq5LTAwa" \
  "https://api.render.com/v1/logs?ownerId=tea-cumojslumphs738ld8fg&resource=srv-da20pelg1s2s73de3n70&limit=100&text=WORKER%20TIMEOUT" \
  | python3 -m json.tool

echo ""
echo "=== 3) Confirm gunicorn --timeout value currently deployed ==="
grep -n "timeout" Procfile render.yaml 2>/dev/null

echo ""
echo "=== 4) Rewrite useVoice.js: toggle-based speak/stop, tracks which message is speaking ==="
cat > src/hooks/useVoice.js << 'VOICEEOF'
import { useCallback, useRef, useState } from "react";

/**
 * Uses the browser's built-in speechSynthesis API. Toggle behavior:
 * tapping Speak on a message starts reading and highlights that button;
 * tapping it again (or tapping Speak on a different message) stops it.
 * (Cloned-voice /api/tts path is not in use — see prior notes on Chatterbox
 * OOM'ing Render free tier. This is speechSynthesis only, not your voice.)
 */
export function useVoice() {
  const utteranceRef = useRef(null);
  const [speakingId, setSpeakingId] = useState(null);

  const toggleSpeak = useCallback((id, text) => {
    if (!("speechSynthesis" in window)) return;

    if (speakingId === id) {
      window.speechSynthesis.cancel();
      setSpeakingId(null);
      return;
    }

    window.speechSynthesis.cancel();
    if (!text) return;

    const utterance = new SpeechSynthesisUtterance(text);
    utterance.rate = 1;
    utterance.pitch = 1;
    utterance.onend = () => setSpeakingId(null);
    utterance.onerror = () => setSpeakingId(null);
    utteranceRef.current = utterance;
    setSpeakingId(id);
    window.speechSynthesis.speak(utterance);
  }, [speakingId]);

  return { toggleSpeak, speakingId };
}
VOICEEOF

echo ""
echo "=== 5) Wire Home.jsx to pass toggleSpeak + speakingId instead of speakText ==="
python3 - << 'PYEOF'
path = "src/pages/Home.jsx"
with open(path) as f:
    content = f.read()

old1 = "const { speakText } = useVoice();"
new1 = "const { toggleSpeak, speakingId } = useVoice();"
if old1 in content:
    content = content.replace(old1, new1)
    print("Home.jsx hook usage updated.")
else:
    print("MANUAL: old useVoice() destructure line not found in Home.jsx")

old2 = 'onSpeak={speakText} />'
new2 = 'onSpeak={toggleSpeak} isSpeaking={speakingId === msg.id} />'
if old2 in content:
    content = content.replace(old2, new2)
    print("Home.jsx MessageBubble props updated.")
else:
    print("MANUAL: old onSpeak prop wiring not found in Home.jsx")

with open(path, "w") as f:
    f.write(content)
PYEOF

echo ""
echo "=== 6) Update MessageBubble.jsx: teal highlight while speaking, click toggles by message.id ==="
python3 - << 'PYEOF'
path = "src/components/omega/MessageBubble.jsx"
with open(path) as f:
    content = f.read()

old_sig = 'export default function MessageBubble({ message, onOpenWorkspace , onSpeak }) {'
new_sig = 'export default function MessageBubble({ message, onOpenWorkspace, onSpeak, isSpeaking }) {'
if old_sig in content:
    content = content.replace(old_sig, new_sig)
    print("Function signature updated.")
else:
    print("MANUAL: function signature not found")

old_click = 'onClick={() => onSpeak(message.content)}'
new_click = 'onClick={() => onSpeak(message.id, message.content)}'
if old_click in content:
    content = content.replace(old_click, new_click)
    print("onClick updated.")
else:
    print("MANUAL: onClick handler not found")

old_btn_class_marker = '<Volume2 className="w-3 h-3" /> Speak'
new_btn_block = '<Volume2 className={`w-3 h-3 ${isSpeaking ? "text-teal-400" : ""}`} /> {isSpeaking ? "Stop" : "Speak"}'
if old_btn_class_marker in content:
    content = content.replace(old_btn_class_marker, new_btn_block)
    print("Button label/icon updated.")
else:
    print("MANUAL: Speak button JSX marker not found")

with open(path, "w") as f:
    f.write(content)
PYEOF

echo ""
echo "=== 7) Show diffs for both files, eyeball before push ==="
git diff src/hooks/useVoice.js src/pages/Home.jsx src/components/omega/MessageBubble.jsx

echo ""
echo "=== 8) Push ==="
git add src/hooks/useVoice.js src/pages/Home.jsx src/components/omega/MessageBubble.jsx
git commit -m "fix: toggle-based Speak/Stop button with teal active state"
git push origin main

echo ""
echo "=== 9) Confirm build succeeds ==="
sleep 25
curl -s "https://api.github.com/repos/tommyleeharvey/omega-agent-v2/actions/workflows/329088611/runs?per_page=3" | python3 -c "
import sys, json
d = json.load(sys.stdin)
for r in d.get('workflow_runs', []):
    print(r['created_at'], '-', r['status'], '-', r['conclusion'], '-', r['head_sha'][:8])
"
