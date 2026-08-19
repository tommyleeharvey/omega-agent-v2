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
