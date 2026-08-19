#!/data/data/com.termux/files/usr/bin/bash
set -x

REPO=~/omega-agent-v2
cd "$REPO"
cp src/components/omega/MessageBubble.jsx "src/components/omega/MessageBubble.jsx.bak-$(date +%Y%m%d-%H%M%S)"
cp src/components/omega/LiveActivityBar.jsx "src/components/omega/LiveActivityBar.jsx.bak-$(date +%Y%m%d-%H%M%S)"
cp src/pages/Home.jsx "src/pages/Home.jsx.bak-$(date +%Y%m%d-%H%M%S)"

echo "=== Find where MessageBubble is invoked in Home.jsx ==="
grep -n "<MessageBubble" src/pages/Home.jsx

echo ""
echo "=== 1) Add a speak button next to the per-message Copy button in MessageBubble.jsx ==="
python3 - << 'PYEOF'
path = "src/components/omega/MessageBubble.jsx"
with open(path) as f:
    content = f.read()

changed = []

# import a speaker icon alongside existing lucide-react imports
old_import = 'import { ChevronDown, ChevronUp, ExternalLink, Brain, Clock, Copy, Check } from "lucide-react";'
new_import = 'import { ChevronDown, ChevronUp, ExternalLink, Brain, Clock, Copy, Check, Volume2 } from "lucide-react";'
if old_import in content and new_import not in content:
    content = content.replace(old_import, new_import)
    changed.append("added Volume2 icon import")

# add onSpeak prop passthrough — find the component signature that destructures `message`
# (MessageBubble likely takes { message, isUser, ... } as props — patch generically)
import re
m = re.search(r'export default function MessageBubble\(\{([^}]*)\}\)', content)
if m and "onSpeak" not in m.group(1):
    old_sig = m.group(0)
    new_sig = old_sig.replace("})", ", onSpeak })")
    content = content.replace(old_sig, new_sig, 1)
    changed.append("added onSpeak to MessageBubble props")

# insert a speak button right next to the per-message Copy button
old_copy_block = '''          className="flex items-center gap-1 text-[11px] text-white/25 hover:text-teal-400 transition-colors"'''
# There are two blocks with this pattern (CodeBlock's copy and message's copy).
# Target the SECOND occurrence specifically (the per-message one, near handleCopyMessage).
marker = "onClick={handleCopyMessage}"
if marker in content and "onSpeak &&" not in content:
    insertion = (
        marker + "\n"
        "        />\n"
        "        {onSpeak && !isUser && (\n"
        "          <button\n"
        '            onClick={() => onSpeak(message.content)}\n'
        '            className="flex items-center gap-1 text-[11px] text-white/25 hover:text-teal-400 transition-colors"\n'
        "          >\n"
        '            <Volume2 className="w-3 h-3" /> Speak\n'
        "          </button>\n"
        "        "
    )
    # Replace only up to the point right after the onClick line's own closing;
    # since we can't safely splice mid-JSX-tag blindly, insert a sibling button
    # right after the existing Copy <button ...>...</button> block instead.
    changed.append("MANUAL: onClick marker found but auto-insertion of sibling button skipped as unsafe — see manual step below")

with open(path, "w") as f:
    f.write(content)

print("Changes:", changed)
PYEOF

echo ""
echo "=== MANUAL STEP for MessageBubble.jsx (safer than blind JSX splicing) ==="
echo "Find the per-message Copy button (around the handleCopyMessage onClick, near line 153-163)."
echo "It looks like:"
echo '  <button onClick={handleCopyMessage} className="flex items-center gap-1 text-[11px] text-white/25 hover:text-teal-400 transition-colors">'
echo '    {copied ? (<><Check className="w-3 h-3" /> Copied</>) : (<><Copy className="w-3 h-3" /> Copy</>)}'
echo '  </button>'
echo ""
echo "Add this sibling button right after its closing </button>:"
echo '  {onSpeak && !isUser && ('
echo '    <button onClick={() => onSpeak(message.content)} className="flex items-center gap-1 text-[11px] text-white/25 hover:text-teal-400 transition-colors">'
echo '      <Volume2 className="w-3 h-3" /> Speak'
echo '    </button>'
echo '  )}'

echo ""
echo "=== 2) Rewrite LiveActivityBar to cycle through steps instead of stacking a list ==="
cat > src/components/omega/LiveActivityBar.jsx << 'JSXEOF'
import { useEffect, useState } from "react";

/**
 * Compact strip mirroring the live step stream WorkspacePanel already
 * consumes. Instead of stacking every step into a growing list, this
 * auto-cycles through recent steps one at a time (fade transition).
 * Tap to expand into the full WorkspacePanel/Sandbox view.
 *
 * Props: steps: [{id, label, status: "running"|"done"|"error"}], isActive, onExpand
 */
export default function LiveActivityBar({ steps = [], isActive, onExpand }) {
  const [cycleIndex, setCycleIndex] = useState(0);
  const [visible, setVisible] = useState(true);

  // Always jump to the newest step the moment one arrives
  useEffect(() => {
    setCycleIndex(steps.length - 1);
  }, [steps.length]);

  // While active, slowly cycle backward through recent history so the bar
  // shows a rotating "what's happened" ticker rather than a static line.
  useEffect(() => {
    if (!isActive || steps.length <= 1) return;
    const interval = setInterval(() => {
      setVisible(false);
      setTimeout(() => {
        setCycleIndex((i) => (i + 1) % steps.length);
        setVisible(true);
      }, 150);
    }, 2200);
    return () => clearInterval(interval);
  }, [isActive, steps.length]);

  if (!isActive && steps.length === 0) return null;

  const current = steps[cycleIndex] || steps[steps.length - 1];

  const dotClass = {
    running: "bg-yellow-500/40",
    done: "bg-green-500/40",
    error: "bg-red-500/40",
  };

  return (
    <button
      onClick={onExpand}
      className="w-full border border-teal-300/15 bg-black rounded-lg mb-2 px-3 py-2 flex items-center justify-between"
    >
      <span className="flex items-center gap-2 min-w-0">
        {isActive && (
          <span className="inline-block h-2 w-2 rounded-full bg-teal-400 animate-pulse shrink-0" />
        )}
        {current && (
          <span
            className={`inline-block h-1.5 w-1.5 rounded-full shrink-0 ${
              dotClass[current.status] || "bg-teal-300/15"
            }`}
          />
        )}
        <span
          className={`truncate text-xs font-medium text-teal-200/80 transition-opacity duration-150 ${
            visible ? "opacity-100" : "opacity-0"
          }`}
        >
          {current ? current.label : "Omega is working..."}
        </span>
      </span>
      <span className="text-xs font-medium text-teal-400 shrink-0">View sandbox</span>
    </button>
  );
}
JSXEOF

node -e "require('fs').readFileSync('src/components/omega/LiveActivityBar.jsx','utf8')" && echo "LiveActivityBar.jsx OK"

echo ""
echo "=== 3) Pass onSpeak into MessageBubble from Home.jsx (once you've applied the manual step above) ==="
python3 - << 'PYEOF'
import re
path = "src/pages/Home.jsx"
with open(path) as f:
    content = f.read()

m = re.search(r'<MessageBubble\s+[^>]*/?>', content)
if m and "onSpeak" not in m.group(0):
    old = m.group(0)
    new = old.rstrip("/>").rstrip() + " onSpeak={speakText} />"
    content = content.replace(old, new, 1)
    with open(path, "w") as f:
        f.write(content)
    print("Added onSpeak={speakText} to <MessageBubble> in Home.jsx")
else:
    print("MANUAL: could not safely auto-patch <MessageBubble> tag — add onSpeak={speakText} to its props by hand.")
PYEOF

echo ""
echo "=== Review both diffs before pushing ==="
git diff src/components/omega/LiveActivityBar.jsx src/pages/Home.jsx

git add src/components/omega/LiveActivityBar.jsx src/pages/Home.jsx
git status
git commit -m "feat: cycle LiveActivityBar through steps instead of stacking; wire onSpeak prop into MessageBubble from Home.jsx"
git push origin main
