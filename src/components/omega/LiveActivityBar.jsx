import { CheckCircle2, Circle, Loader2, XCircle } from "lucide-react";

/**
 * Manus-style live step list: shows every step Omega has taken on the
 * current job as a persistent vertical list, not a cycling ticker hidden
 * behind a tap. Running steps show a spinner, done steps a check, error
 * steps an X. Stays visible for the duration of the job so the user can
 * see reasoning/tool-use happen in real time instead of just a spinner.
 *
 * Props: steps: [{id, label, status: "running"|"done"|"error"}], isActive, onExpand
 */
export default function LiveActivityBar({ steps = [], isActive, onExpand }) {
  if (!isActive && steps.length === 0) return null;

  const icon = (status) => {
    if (status === "running") return <Loader2 className="w-3.5 h-3.5 text-yellow-400 animate-spin shrink-0" />;
    if (status === "done") return <CheckCircle2 className="w-3.5 h-3.5 text-green-400 shrink-0" />;
    if (status === "error") return <XCircle className="w-3.5 h-3.5 text-red-400 shrink-0" />;
    return <Circle className="w-3.5 h-3.5 text-white/20 shrink-0" />;
  };

  return (
    <div className="w-full border border-teal-300/15 bg-black rounded-lg mb-2 overflow-hidden">
      <button
        onClick={onExpand}
        className="w-full px-3 py-2 flex items-center justify-between border-b border-teal-300/10"
      >
        <span className="flex items-center gap-2">
          {isActive && (
            <span className="inline-block h-2 w-2 rounded-full bg-teal-400 animate-pulse shrink-0" />
          )}
          <span className="text-xs font-medium text-teal-200/80">
            {isActive ? "Omega is working..." : "Steps"}
          </span>
        </span>
        <span className="text-xs font-medium text-teal-400 shrink-0">View sandbox</span>
      </button>
      {steps.length > 0 && (
        <div className="max-h-40 overflow-y-auto px-3 py-2 space-y-1.5">
          {steps.map((step) => (
            <div key={step.id} className="flex items-center gap-2 min-w-0">
              {icon(step.status)}
              <span
                className={`truncate text-xs ${
                  step.status === "running" ? "text-white/90" : "text-white/40"
                }`}
              >
                {step.label}
              </span>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
