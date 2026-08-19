#!/data/data/com.termux/files/usr/bin/bash
set -x

echo "=== Remove the redundant local ping job, keep only the crond watchdog ==="
crontab -l 2>/dev/null | grep -v "ping_backend.sh" | crontab -
crontab -l

echo ""
echo "=== Confirm watchdog still present ==="
crontab -l | grep "cron_watchdog.sh" || echo "MANUAL: watchdog missing, re-add with: (crontab -l; echo '*/15 * * * * ~/omega_workspace/omega-agent-v2/cron_watchdog.sh') | crontab -"
