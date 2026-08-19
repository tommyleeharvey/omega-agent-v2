#!/data/data/com.termux/files/usr/bin/bash
set -x

REPO=~/omega-agent-v2
cd "$REPO"

mkdir -p src/components/omega
cat > src/components/omega/VoiceToggle.jsx << 'JSXEOF'
import { useState } from "react";

/**
 * Voice on/off toggle. When on, the parent should call speakText(text)
 * after each assistant response finishes (see hook below).
 */
export default function VoiceToggle({ enabled, onToggle }) {
  return (
    <button
      onClick={() => onToggle(!enabled)}
      className={`flex items-center gap-1.5 px-2 py-1 rounded-md text-xs border transition-colors ${
        enabled
          ? "border-teal-400 text-teal-300 bg-teal-500/10"
          : "border-white/10 text-white/40"
      }`}
      title={enabled ? "Voice: on" : "Voice: off"}
    >
      {enabled ? "🔊" : "🔇"}
    </button>
  );
}
JSXEOF

cat > src/hooks/useVoice.js << 'JSEOF'
import { useCallback, useRef, useState } from "react";

const TTS_ENDPOINT =
  (import.meta.env.VITE_AGENT_BACKEND_URL || "") + "/api/tts";

export function useVoice() {
  const [voiceEnabled, setVoiceEnabled] = useState(
    localStorage.getItem("omega_voice_enabled") === "true"
  );
  const audioRef = useRef(null);

  const setVoicePref = useCallback((val) => {
    setVoiceEnabled(val);
    localStorage.setItem("omega_voice_enabled", String(val));
    if (!val && audioRef.current) {
      audioRef.current.pause();
    }
  }, []);

  const speakText = useCallback(
    async (text) => {
      if (!voiceEnabled || !text) return;
      try {
        const res = await fetch(TTS_ENDPOINT, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ text }),
        });
        if (!res.ok) return;
        const blob = await res.blob();
        const url = URL.createObjectURL(blob);
        if (audioRef.current) audioRef.current.pause();
        audioRef.current = new Audio(url);
        audioRef.current.play();
      } catch (e) {
        console.error("TTS playback failed:", e);
      }
    },
    [voiceEnabled]
  );

  return { voiceEnabled, setVoicePref, speakText };
}
JSEOF

echo "=== Sanity checks ==="
node -e "require('fs').readFileSync('src/components/omega/VoiceToggle.jsx','utf8')" && echo "VoiceToggle.jsx OK"
node -e "require('fs').readFileSync('src/hooks/useVoice.js','utf8')" && echo "useVoice.js OK"

echo ""
echo "=== Show where the chat header/toolbar and assistant-response-received code live in Home.jsx (for manual wiring) ==="
grep -n "response.trim\|setMessages\|assistant.*content\|header\|toolbar" src/pages/Home.jsx | head -20

echo ""
echo "=== MANUAL STEP (required) ==="
echo "In src/pages/Home.jsx:"
echo '1. import { useVoice } from "../hooks/useVoice";'
echo '   import VoiceToggle from "../components/omega/VoiceToggle";'
echo "2. Inside the component: const { voiceEnabled, setVoicePref, speakText } = useVoice();"
echo "3. Render near the chat header/toolbar:"
echo '     <VoiceToggle enabled={voiceEnabled} onToggle={setVoicePref} />'
echo "4. Wherever the assistant's final response text lands (setMessages(...) with"
echo "   the completed assistant message), call: speakText(finalResponseText);"
echo ""
echo "NOTE: this depends on /api/tts actually being live — last check it was still"
echo "404ing on Render (Chatterbox model likely didn't finish downloading / OOM'd"
echo "on the free tier). Confirm that's resolved before this toggle will do anything."

git add src/components/omega/VoiceToggle.jsx src/hooks/useVoice.js
git status
git commit -m "feat: add voice on/off toggle + useVoice hook (calls /api/tts, plays response audio)"
git push origin main
