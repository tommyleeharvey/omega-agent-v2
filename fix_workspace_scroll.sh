#!/data/data/com.termux/files/usr/bin/bash
set -x

REPO=~/omega-agent-v2
cd "$REPO"
TARGET=src/components/omega/WorkspacePanel.jsx

test -f "$TARGET" && echo "found" || { echo "NOT FOUND — locating..."; find . -iname "WorkspacePanel*" -not -path "*/node_modules/*"; exit 1; }

echo "=== Current overflow/height handling ==="
grep -n "overflow\|max-h-\|h-screen\|flex-1\|min-h-0" "$TARGET"

cp "$TARGET" "${TARGET}.bak-$(date +%Y%m%d-%H%M%S)"

python3 - << 'PYEOF'
import re

path = "src/components/omega/WorkspacePanel.jsx"
with open(path) as f:
    content = f.read()

changed = False

if "overflow-y-auto" in content:
    print("overflow-y-auto already present somewhere — nothing to do.")
else:
    patterns = [
        (r'(className="[^"]*)(flex-col[^"]*")(\s*>\s*\{/\*\s*tab content|\s*>\s*\{activeTab)',
         r'\1flex-col overflow-y-auto min-h-0\2\3'),
    ]
    for pat, repl in patterns:
        new_content, n = re.subn(pat, repl, content)
        if n:
            content = new_content
            changed = True
            print(f"Applied targeted pattern, {n} replacement(s).")
            break
    if not changed:
        print("Could not find a safe automatic insertion point.")
        print("MANUAL STEP: find the div wrapping the Actions/Browser/Terminal/Files")
        print("tab content and add Tailwind classes: flex-1 min-h-0 overflow-y-auto")
        print("(add 'flex flex-col' to its parent too if not already present)")

with open(path, "w") as f:
    f.write(content)
print("changed:", changed)
PYEOF

echo ""
echo "=== Review diff before pushing ==="
git diff "$TARGET"
echo ""
echo "If it looks wrong: cp ${TARGET}.bak-* $TARGET   (then edit manually)"

git add "$TARGET"
git status
git commit -m "fix: make Omega Sandbox WorkspacePanel content area scrollable"
git push origin main
