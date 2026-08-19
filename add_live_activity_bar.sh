#!/data/data/com.termux/files/usr/bin/bash
set -x

REPO=~/omega-agent-v2
cd "$REPO"

mkdir -p src/components/omega
cat > src/components/omega/LiveActivityBar.jsx << 'JSXEOF'
import { useState } from "react";

/**
 * Compact strip mirroring the same live step stream WorkspacePanel already
 * consumes (SSE from /api/job/stream/<id>). Tap to expand/collapse; onExpand
 * jumps into the full WorkspacePanel/Sandbox view.
 *
 * Props: steps: [{id, label, status: "running"|"done"|"error"}], isActive, onExpand
 */
export default function LiveActivityBar({ steps = [], isActive, onExpand }) {
  const [collapsed, setCollapsed] = useState(false);
  if (!isActive && steps.length === 0) return null;
  const latest = steps[steps.length - 1];

  return (
    <div className="w-full border border-teal-500/30 bg-black/90 rounded-lg mb-2 text-sm text-teal-300">
      <button className="w-full flex items-center justify-between px-3 py-2" onClick={() => setCollapsed((c) => !c)}>
        <span className="flex items-center gap-2 truncate">
          {isActive && <span className="inline-block h-2 w-2 rounded-full bg-teal-400 animate-pulse" />}
          <span className="truncate">{latest ? latest.label : "Omega is working..."}</span>
        </span>
        <span className="flex items-center gap-3 shrink-0">
          <span className="underline text-teal-400" onClick={(e) => { e.stopPropagation(); onExpand && onExpand(); }}>
            View sandbox
          </span>
          <span>{collapsed ? "▸" : "▾"}</span>
        </span>
      </button>
      {!collapsed && (
        <div className="px-3 pb-2 max-h-40 overflow-y-auto space-y-1">
          {steps.map((s) => (
            <div key={s.id} className="flex items-center gap-2 text-xs">
              <span>{s.status === "done" && "✅"}{s.status === "running" && "⏳"}{s.status === "error" && "❌"}</span>
              <span className="truncate">{s.label}</span>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
JSXEOF

echo "=== Sanity check the file is readable ==="
node -e "require('fs').readFileSync('src/components/omega/LiveActivityBar.jsx','utf8')" && echo "OK"

echo ""
echo "=== Show existing step/stream state in Home.jsx (to wire manually below) ==="
grep -n "WorkspacePanel\|SSE\|EventSource\|onStep\|on_step\|job/stream" src/pages/Home.jsx | head -30

python3 - << 'PYEOF'
import re
path = "src/pages/Home.jsx"
with open(path) as f:
    content = f.read()

if "LiveActivityBar" not in content:
    if "WorkspacePanel" in content:
        m = re.search(r'(import WorkspacePanel from ["\'].*WorkspacePanel["\'];?)', content)
        if m:
            content = content.replace(m.group(1), m.group(1) + '\nimport LiveActivityBar from "../components/omega/LiveActivityBar";', 1)
            with open(path, "w") as f:
                f.write(content)
            print("Inserted LiveActivityBar import next to WorkspacePanel import.")
        else:
            print("Could not anchor import automatically.")
    else:
        print("Could not find WorkspacePanel import to anchor next to.")
else:
    print("Already imported, skipping.")
PYEOF

echo ""
echo "=== MANUAL STEP (required — JSX placement varies too much to patch blindly) ==="
echo "In src/pages/Home.jsx, above your chat input, render:"
echo ""
echo '  <LiveActivityBar'
echo '    steps={transcriptSteps.map(s => ({ id: s.id, label: s.label || s.tool_name, status: s.status }))}'
echo '    isActive={isJobRunning}'
echo '    onExpand={() => setShowWorkspacePanel(true)}'
echo '  />'
echo ""
echo "Use your existing transcript/step state (same one WorkspacePanel already reads) —"
echo "no new backend or SSE work needed, just a second render target."

git add src/components/omega/LiveActivityBar.jsx src/pages/Home.jsx
git status
git commit -m "feat: add LiveActivityBar (compact live agent-step view above chat input)"
git push origin main
