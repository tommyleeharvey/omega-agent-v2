#!/data/data/com.termux/files/usr/bin/bash
set -x

REPO=~/omega-agent-v2
cd "$REPO"

echo "=== Tailwind config (custom colors/fonts/spacing, if any) ==="
cat tailwind.config.js 2>/dev/null || cat tailwind.config.ts 2>/dev/null || echo "no tailwind.config found at root"

echo ""
echo "=== Color/border/bg classes actually used in WorkspacePanel.jsx ==="
grep -oE 'className="[^"]*"' src/components/omega/WorkspacePanel.jsx | grep -oE '\b(bg|text|border)-[a-z]+-[0-9]+(/[0-9]+)?\b' | sort -u

echo ""
echo "=== Same, for Home.jsx (chat UI itself) ==="
grep -oE 'className="[^"]*"' src/pages/Home.jsx | grep -oE '\b(bg|text|border)-[a-z]+-[0-9]+(/[0-9]+)?\b' | sort -u

echo ""
echo "=== Font family / weight classes in use ==="
grep -oE '\bfont-[a-z]+\b' src/pages/Home.jsx src/components/omega/WorkspacePanel.jsx | sort -u

echo ""
echo "=== Rounded-corner and shadow conventions ==="
grep -oE '\brounded-[a-z0-9-]+\b|\bshadow-[a-z0-9-]*\b' src/pages/Home.jsx src/components/omega/WorkspacePanel.jsx | sort -u

echo ""
echo "=== Spacing scale actually used for buttons/badges (px-*/py-* on small elements) ==="
grep -oE '\b(px|py)-[0-9.]+\b' src/components/omega/WorkspacePanel.jsx | sort | uniq -c | sort -rn | head -10
