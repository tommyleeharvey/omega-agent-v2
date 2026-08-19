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
