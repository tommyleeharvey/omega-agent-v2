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

  const dotClass = {
    running: "bg-yellow-500/40",
    done: "bg-green-500/40",
    error: "bg-red-500/40",
  };

  return (
    <div className="w-full border border-teal-300/15 bg-black rounded-lg mb-2">
      <button
        className="w-full flex items-center justify-between px-3 py-2"
        onClick={() => setCollapsed((c) => !c)}
      >
        <span className="flex items-center gap-2 min-w-0">
          {isActive && (
            <span className="inline-block h-2 w-2 rounded-full bg-teal-400 animate-pulse shrink-0" />
          )}
          <span className="truncate text-xs font-medium text-teal-200/80">
            {latest ? latest.label : "Omega is working..."}
          </span>
        </span>
        <span className="flex items-center gap-3 shrink-0">
          <span
            className="text-xs font-medium text-teal-400"
            onClick={(e) => {
              e.stopPropagation();
              onExpand && onExpand();
            }}
          >
            View sandbox
          </span>
          <span className="text-teal-200/45 text-xs">{collapsed ? "▸" : "▾"}</span>
        </span>
      </button>

      {!collapsed && (
        <div className="px-3 pb-2 max-h-40 overflow-y-auto space-y-1">
          {steps.map((s) => (
            <div key={s.id} className="flex items-center gap-2">
              <span
                className={`inline-block h-1.5 w-1.5 rounded-full shrink-0 ${
                  dotClass[s.status] || "bg-teal-300/15"
                }`}
              />
              <span className="truncate text-[11px] font-mono text-teal-200/45">
                {s.label}
              </span>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
