#!/data/data/com.termux/files/usr/bin/bash
set -x

echo "SCRIPT STARTED at $(date)"

BACKEND="https://omega-agent-backend-v2.onrender.com"
LOG=~/omega_workspace/omega-agent-v2/poll_tts.log
echo "Polling started $(date)" > "$LOG"

for i in $(seq 1 45); do
  CODE=$(curl -s -o /tmp/tts_body.txt -w "%{http_code}" -X POST "$BACKEND/api/tts" -H "Content-Type: application/json" -d '{"text":"test"}' --max-time 15)
  echo "[$i] $(date +%H:%M:%S) status=$CODE" | tee -a "$LOG"
  if [ "$CODE" != "404" ]; then
    echo "NON-404 RESPONSE - stopping poll" | tee -a "$LOG"
    echo "--- response body (first 500 chars) ---" | tee -a "$LOG"
    head -c 500 /tmp/tts_body.txt | tee -a "$LOG"
    echo "" | tee -a "$LOG"
    break
  fi
  sleep 20
done

echo ""
echo "=== Full log saved at $LOG - cat it if this terminal output gets cut off ==="
cat "$LOG"
