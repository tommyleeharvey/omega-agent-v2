#!/data/data/com.termux/files/usr/bin/bash
set -x

RUN_ID=32215074628

echo "=== Get job ID for the failed 'build' job ==="
JOB_ID=$(curl -s "https://api.github.com/repos/tommyleeharvey/omega-agent-v2/actions/runs/$RUN_ID/jobs" | python3 -c "
import sys, json
d = json.load(sys.stdin)
for j in d['jobs']:
    if j['name'] == 'build':
        print(j['id'])
")
echo "Job ID: $JOB_ID"

echo ""
echo "=== Download full log for that job ==="
curl -s -L -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/tommyleeharvey/omega-agent-v2/actions/jobs/$JOB_ID/logs" \
  -o /tmp/build_fail.log 2>/dev/null || \
curl -s -L -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/tommyleeharvey/omega-agent-v2/actions/jobs/$JOB_ID/logs" \
  -o ~/build_fail.log

LOGFILE=/tmp/build_fail.log
[ -s "$LOGFILE" ] || LOGFILE=~/build_fail.log

echo ""
echo "=== Show only the error-relevant lines (last 80 lines, or grep for common failure markers) ==="
grep -n -i "error\|fail\|Module not found\|Cannot find\|Unexpected token\|SyntaxError" "$LOGFILE" | tail -60

echo ""
echo "=== If nothing matched above, show the last 100 raw lines instead ==="
tail -100 "$LOGFILE"
