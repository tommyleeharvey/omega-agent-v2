#!/data/data/com.termux/files/usr/bin/bash
set -x
echo "=== Show the matching line(s), key masked to first/last 8 chars ==="
grep -oE "sk-ant-[A-Za-z0-9_-]{10,}" /data/data/com.termux/files/home/.omega/nexus/.env | while read -r k; do
  echo "${k:0:12}...${k: -6} (length: ${#k})"
done

echo ""
echo "=== Show the variable name it's assigned to, so we know it's really an API key and not something else ==="
grep -n "sk-ant-" /data/data/com.termux/files/home/.omega/nexus/.env | sed -E 's/(sk-ant-)[A-Za-z0-9_-]{10,}/\1***MASKED***/'
