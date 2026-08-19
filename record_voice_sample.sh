#!/data/data/com.termux/files/usr/bin/bash
set -x

# Requires the Termux:API app installed from F-Droid/Play Store + `pkg install termux-api`
# If you'd rather use your phone's normal voice recorder app instead, skip this script,
# record ~30-60s of clean speech there, then `cp` or share the file into:
#   ~/omega_workspace/omega-agent-v2/voice_samples/my_voice.wav

mkdir -p ~/omega_workspace/omega-agent-v2/voice_samples

echo "=== Recording 45 seconds. Speak naturally, varied sentences, quiet room, no music/echo. ==="
echo "=== Read a paragraph aloud, or just talk about your day for the full 45s. ==="
termux-microphone-record -f ~/omega_workspace/omega-agent-v2/voice_samples/my_voice.wav -l 45

sleep 46

echo ""
echo "=== Done. Sample saved to: ==="
ls -lh ~/omega_workspace/omega-agent-v2/voice_samples/my_voice.wav
