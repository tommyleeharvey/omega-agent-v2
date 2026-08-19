#!/data/data/com.termux/files/usr/bin/bash
cd ~/omega-agent-v2

TOKEN=$(grep -oP "(?<=Bearer )[a-zA-Z0-9_-]+" apply_gemini_key.sh | head -1)

if [ -z "$TOKEN" ]; then
  echo "Could not find token."
  exit 1
fi

set -x
curl -s -H "Authorization: Bearer $TOKEN" \
  "https://api.render.com/v1/services/srv-da20pelg1s2s73de3n70/logs?limit=50" \
  > raw_render_logs.json 2>&1
set +x

echo "=== raw response, first 500 chars (to see actual shape) ==="
head -c 500 raw_render_logs.json
echo ""
echo ""
echo "=== attempting NDJSON parse ==="
python3 -c "
import json
with open('raw_render_logs.json') as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        try:
            entry = json.loads(line)
            msg = entry.get('message', entry) if isinstance(entry, dict) else entry
            print(msg)
        except Exception:
            pass
"
rm -f raw_render_logs.json
