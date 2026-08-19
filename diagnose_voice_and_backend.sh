#!/data/data/com.termux/files/usr/bin/bash
set -x

echo "=== Is the termux-api package installed? ==="
pkg list-installed 2>/dev/null | grep -i termux-api || echo "NOT INSTALLED - run: pkg install termux-api"

echo ""
echo "=== Is termux-microphone-record on PATH? ==="
which termux-microphone-record || echo "NOT FOUND"

echo ""
echo "=== Try recording again with verbose error output (5s test) ==="
mkdir -p ~/omega_workspace/omega-agent-v2/voice_samples
termux-microphone-record -f ~/omega_workspace/omega-agent-v2/voice_samples/test.wav -l 5
sleep 6
ls -lh ~/omega_workspace/omega-agent-v2/voice_samples/ 2>&1

echo ""
echo "=== Check mic recording status/info command if available ==="
termux-microphone-record -i 2>&1 || true

echo ""
echo "=== NOTE: if NOT INSTALLED above, you also need the Termux:API companion APP ==="
echo "(separate from the pkg) from F-Droid or Play Store, and grant it microphone permission"
echo "in Android Settings > Apps > Termux:API > Permissions. Without the app + permission,"
echo "the command fails silently with no file written, which matches what happened."

echo ""
echo "=== Locate the real backend entrypoint (search for Flask app creation) ==="
REPO=~/omega-agent-v2
cd "$REPO"
grep -rln "Flask(__name__)\|Flask(\"" --include="*.py" . 2>/dev/null

echo ""
echo "=== Show top of each candidate file found above ==="
for f in $(grep -rln "Flask(__name__)\|Flask(\"" --include="*.py" .); do
  echo "--- $f ---"
  head -30 "$f"
  echo ""
done
