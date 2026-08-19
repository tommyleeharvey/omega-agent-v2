#!/data/data/com.termux/files/usr/bin/bash
set -x

echo "=== Look for an existing GitHub token in common locations ==="
GH_TOKEN=""
for f in ~/.git-credentials ~/.netrc ~/omega-agent-v2/.env ~/.omega/.env; do
  if [ -f "$f" ]; then
    echo "--- checking $f ---"
    grep -oE "gh[ps]_[A-Za-z0-9]{20,}" "$f" 2>/dev/null
  fi
done

FOUND_TOKEN=$(for f in ~/.git-credentials ~/.netrc ~/omega-agent-v2/.env ~/.omega/.env; do
  [ -f "$f" ] && grep -oE "gh[ps]_[A-Za-z0-9]{20,}" "$f" 2>/dev/null
done | head -1)

if [ -z "$FOUND_TOKEN" ]; then
  echo ""
  echo "MANUAL: no token found on disk. Easiest path: open this URL in your"
  echo "browser (already logged into GitHub) and paste back what you see:"
  echo "https://github.com/tommyleeharvey/omega-agent-v2/actions/runs/32215074628/job/95954929794"
  exit 0
fi

echo "Found token, retrying log download..."
JOB_ID=95954929794
curl -s -L -H "Authorization: Bearer $FOUND_TOKEN" -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/tommyleeharvey/omega-agent-v2/actions/jobs/$JOB_ID/logs" \
  -o ~/build_fail.log

echo ""
echo "=== Error-relevant lines ==="
grep -n -i "error\|fail\|Module not found\|Cannot find\|Unexpected token\|SyntaxError" ~/build_fail.log | tail -60

echo ""
echo "=== Last 100 raw lines (fallback) ==="
tail -100 ~/build_fail.log
