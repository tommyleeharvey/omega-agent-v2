#!/data/data/com.termux/files/usr/bin/bash
set -x
REPO=~/omega-agent-v2
cd "$REPO"
find . -iname "transcriptAdapter*" -not -path "*/node_modules/*"
cat -n src/lib/transcriptAdapter.js 2>/dev/null || find . -iname "transcriptAdapter*" -not -path "*/node_modules/*" -exec cat -n {} \;
