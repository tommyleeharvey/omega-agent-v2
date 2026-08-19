#!/data/data/com.termux/files/usr/bin/bash
set -x

echo "=== Full remote config for this local repo ==="
git -C ~/omega-agent-v2 remote -v

echo ""
echo "=== Recent commit history (who's been pushing here) ==="
git -C ~/omega-agent-v2 log --oneline -10

echo ""
echo "=== What's actually on the remote right now (the commits we don't have locally) ==="
git -C ~/omega-agent-v2 fetch origin
git -C ~/omega-agent-v2 log HEAD..origin/main --oneline

echo ""
echo "=== Is cipherxsniper/omega-agent-v2 a fork? Of what? ==="
curl -s "https://api.github.com/repos/cipherxsniper/omega-agent-v2" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print('fork:', d.get('fork'))
if d.get('fork'):
    print('parent:', d.get('parent', {}).get('full_name'))
print('owner:', d.get('owner', {}).get('login'))
"

echo ""
echo "=== Does tommyleeharvey/omega-agent-v2 exist separately? ==="
curl -s "https://api.github.com/repos/tommyleeharvey/omega-agent-v2" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print('exists:', 'name' in d, '-', d.get('message',''))
print('fork:', d.get('fork'))
"

echo ""
echo "=== Which repo does tommyleeharvey.github.io/omega-agent-v2/ Pages actually deploy from? ==="
curl -s "https://api.github.com/repos/tommyleeharvey/omega-agent-v2/pages" | python3 -m json.tool
