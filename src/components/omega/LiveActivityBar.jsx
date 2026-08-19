import { AnimatePresence, motion } from "framer-motion";
import { CheckCircle2, Circle, Loader2, XCircle } from "lucide-react";

const MAX_VISIBLE = 4;

export default function LiveActivityBar({ steps = [], isActive, onExpand }) {
  if (!isActive && steps.length === 0) return null;

  const visible = steps.slice(-MAX_VISIBLE);

  const icon = (status) => {
    if (status === "running") return <Loader2 className="w-3.5 h-3.5 text-yellow-400 animate-spin shrink-0" />;
    if (status === "completed") return <CheckCircle2 className="w-3.5 h-3.5 text-green-400 shrink-0" />;
    if (status === "failed") return <XCircle className="w-3.5 h-3.5 text-red-400 shrink-0" />;
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
      {visible.length > 0 && (
        <div className="px-3 py-2 space-y-1.5">
          <AnimatePresence initial={false}>
            {visible.map((step) => (
              <motion.div
                key={step.id}
                initial={{ opacity: 0, y: 6 }}
                animate={{ opacity: 1, y: 0 }}
                exit={{ opacity: 0, y: -6 }}
                transition={{ duration: 0.25 }}
                className="flex items-center gap-2 min-w-0"
              >
                {icon(step.status)}
                <span
                  className={`truncate text-xs ${
                    step.status === "running" ? "text-white/90" : "text-white/40"
                  }`}
                >
                  {step.label}
                </span>
              </motion.div>
            ))}
          </AnimatePresence>
        </div>
      )}
    </div>
  );
}
