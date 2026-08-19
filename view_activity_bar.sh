#!/data/data/com.termux/files/usr/bin/bash
set -x
cat -n ~/omega-agent-v2/src/components/omega/LiveActivityBar.jsx
echo ""
echo "=== Show how it's mounted in Home.jsx around line 638 ==="
sed -n '625,650p' ~/omega-agent-v2/src/pages/Home.jsx
