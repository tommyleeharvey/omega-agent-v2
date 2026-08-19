#!/data/data/com.termux/files/usr/bin/bash
set -x

echo "=== searching installed packages for Termux:Boot ==="
pm list packages 2>/dev/null | grep -i "termux.boot"

echo ""
echo "=== also checking for it under the com.termux namespace broadly ==="
pm list packages 2>/dev/null | grep -i "termux"

echo ""
echo "=== also check tailscale login status while we're here ==="
tailscale status
