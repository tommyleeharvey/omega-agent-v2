#!/data/data/com.termux/files/usr/bin/bash
set -x
(crontab -l 2>/dev/null; echo '*/15 * * * * ~/omega_workspace/omega-agent-v2/cron_watchdog.sh') | crontab -
crontab -l
