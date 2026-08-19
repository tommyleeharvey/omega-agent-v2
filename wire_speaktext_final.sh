#!/data/data/com.termux/files/usr/bin/bash
set -x

REPO=~/omega-agent-v2
cd "$REPO"
cp src/pages/Home.jsx "src/pages/Home.jsx.bak-$(date +%Y%m%d-%H%M%S)"

echo "=== Confirm exact text around line 528 before patching ==="
sed -n '525,530p' src/pages/Home.jsx

echo ""
echo "=== Insert speakText(content) right after the assistant message is pushed into state ==="
python3 - << 'PYEOF'
path = "src/pages/Home.jsx"
with open(path) as f:
    content = f.read()

marker = "setMessages((prev) => [...prev, assistantMsg]);"
count = content.count(marker)
print(f"Marker occurrences found: {count}")

if count == 1:
    content = content.replace(
        marker,
        marker + "\n    speakText(content);"
    )
    with open(path, "w") as f:
        f.write(content)
    print("Inserted speakText(content) after the assistant message lands in state.")
else:
    print("MANUAL: marker count was not exactly 1 — insert by hand to avoid patching the wrong occurrence.")
PYEOF

echo ""
echo "=== Review the diff ==="
git diff src/pages/Home.jsx

echo ""
echo "If wrong: cp src/pages/Home.jsx.bak-* src/pages/Home.jsx"

git add src/pages/Home.jsx
git status
git commit -m "feat: speak the assistant's final response via speakText when voice toggle is on"
git push origin main

echo ""
echo "=== Trigger a fresh Render deploy check afterward (frontend deploys via GitHub Pages Action, not Render — this just confirms backend is still healthy) ==="
curl -s -o /dev/null -w "HTTP %{http_code}\n" https://omega-agent-backend-v2.onrender.com/api/health
