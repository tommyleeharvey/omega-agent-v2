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
