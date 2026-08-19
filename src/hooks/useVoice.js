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
