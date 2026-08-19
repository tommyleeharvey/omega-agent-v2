#!/data/data/com.termux/files/usr/bin/bash
set -x

echo "=== 1) Install cron in Termux if missing ==="
pkg list-installed 2>/dev/null | grep -q "^cronie" || pkg install -y cronie

echo ""
echo "=== 2) Write the ping script cron will call ==="
mkdir -p ~/omega_workspace/omega-agent-v2
cat > ~/omega_workspace/omega-agent-v2/ping_backend.sh << 'PINGEOF'
#!/data/data/com.termux/files/usr/bin/bash
curl -s -o /dev/null -w "%(date)T HTTP %{http_code}\n" https://omega-agent-backend-v2.onrender.com/api/health >> ~/omega_workspace/omega-agent-v2/keepwarm.log 2>&1
PINGEOF
chmod +x ~/omega_workspace/omega-agent-v2/ping_backend.sh

echo ""
echo "=== 3) Register the cron job — every 10 minutes ==="
( crontab -l 2>/dev/null | grep -v "ping_backend.sh" ; echo "*/10 * * * * ~/omega_workspace/omega-agent-v2/ping_backend.sh" ) | crontab -
crontab -l

echo ""
echo "=== 4) Start the cron daemon now, and on Termux boot ==="
crond
echo ""
echo "NOTE: crond dies when Termux is killed by Android. To reduce that, install"
echo "Termux:Boot from F-Droid and drop a copy of this start command in"
echo "~/.termux/boot/ so cron restarts automatically after a reboot."

echo ""
echo "=== 5) Test the ping once right now ==="
~/omega_workspace/omega-agent-v2/ping_backend.sh
cat ~/omega_workspace/omega-agent-v2/keepwarm.log

echo ""
echo "=================================================================="
echo "MANUAL STEP (the reliable one — free, no phone dependency):"
echo "1. Go to https://uptimerobot.com and create a free account"
echo "2. Add New Monitor -> HTTP(s)"
echo "3. URL: https://omega-agent-backend-v2.onrender.com/api/health"
echo "4. Interval: 5 minutes (free tier allows this)"
echo "5. Save"
echo "This alone will likely keep the service warm even if your phone is off."
echo "=================================================================="
