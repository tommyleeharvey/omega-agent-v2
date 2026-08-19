#!/data/data/com.termux/files/usr/bin/bash
set -x

echo "=== installing tmux ==="
pkg install tmux -y

echo ""
echo "=== updating boot script to watchdog version ==="
cat > ~/.termux/boot/start-omega.sh << 'INNER'
#!/data/data/com.termux/files/usr/bin/bash
termux-wake-lock
cd ~/omega-agent-v2
while true; do
  tmux new-session -d -s omega "python3 agent/main.py"
  sleep 5
  while tmux has-session -t omega 2>/dev/null; do sleep 10; done
done
INNER
chmod +x ~/.termux/boot/start-omega.sh

echo ""
echo "=== boot script now reads: ==="
cat ~/.termux/boot/start-omega.sh

echo ""
echo "=== tmux version check ==="
tmux -V
