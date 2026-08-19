#!/data/data/com.termux/files/usr/bin/bash
set -x

echo "=== 1) is tmux installed? ==="
command -v tmux || echo "MISSING: run 'pkg install tmux -y'"

echo ""
echo "=== 2) is tailscale installed? ==="
command -v tailscale || echo "MISSING: run 'pkg install tailscale -y'"

echo ""
echo "=== 3) is termux-services / termux-api installed? ==="
command -v termux-wake-lock || echo "MISSING: run 'pkg install termux-api -y'"

echo ""
echo "=== 4) boot script contents (confirm it's what we expect) ==="
cat ~/.termux/boot/start-omega.sh

echo ""
echo "=== 5) is Termux:Boot app actually installed on the phone? ==="
pm list packages 2>/dev/null | grep -i "termux.boot" || echo "Check manually - Termux:Boot must be installed from F-Droid separately, this check may not detect it"

echo ""
echo "=== 6) current tailscale status (if installed) ==="
tailscale status 2>&1 || echo "not running / not logged in yet"
