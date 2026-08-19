#!/data/data/com.termux/files/usr/bin/bash
curl -s -o /dev/null -w "%(date)T HTTP %{http_code}\n" https://omega-agent-backend-v2.onrender.com/api/health >> ~/omega_workspace/omega-agent-v2/keepwarm.log 2>&1
