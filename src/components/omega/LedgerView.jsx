import React, { useState } from "react";
import { Blocks, ShieldCheck, ChevronDown, ChevronRight, Sparkle } from "lucide-react";

function shortHash(value = "") {
  return value ? `${value.slice(0, 10)}…${value.slice(-8)}` : null;
}

// agentproof chain, rendered as a vertical block ledger. Reads step.entry_hash
// / step.hash if the parent ever passes signed entries down (e.g. from a
// grounding_check or agent_final event); otherwise a block shows as
// "unsealed" rather than faking a hash — this view never invents proof data.
export default function LedgerView({ steps = [], proofId, isThinking }) {
  const [openId, setOpenId] = useState(null);

  const blocks = steps.map((step, index) => ({
    index,
    id: step.id ?? index,
    label: step.label || step.type || `step ${index + 1}`,
    status: step.status || "pending",
    hash: step.entry_hash || step.hash || null,
  }));

  const newestId = blocks.length ? blocks[blocks.length - 1].id : null;

  if (blocks.length === 0) {
    return (
      <div className="flex flex-col items-center justify-center py-14">
        <Blocks className="w-7 h-7 text-white/10 mb-2.5" />
        <p className="text-white/35 text-xs font-medium">Chain is empty</p>
        <p className="text-white/15 text-[10px] mt-1">Signed entries appear here as Omega works</p>
      </div>
    );
  }

  return (
    <div className="px-3 py-3">
      <div className="mb-3 flex items-center justify-between">
        <span className="flex items-center gap-1.5 text-[9px] font-mono uppercase tracking-[0.16em] text-teal-200/60">
          <Blocks className="h-3 w-3" /> agentproof chain
        </span>
        {proofId && (
          <span className="rounded-full border border-teal-300/15 bg-teal-300/[0.04] px-2 py-0.5 font-mono text-[9px] text-teal-200/50">
            root {proofId.slice(0, 10)}
          </span>
        )}
      </div>

      {/* genesis marker */}
      <div className="relative pl-5 pb-1">
        <span className="absolute left-[7px] top-2 bottom-[-2px] w-px bg-gradient-to-b from-white/15 to-teal-300/15" />
        <span className="absolute left-0 top-0.5 h-3.5 w-3.5 rounded-full border border-white/15 bg-white/[0.03]" />
        <span className="text-[9px] font-mono uppercase tracking-wider text-white/25">genesis</span>
      </div>

      <div className="space-y-0">
        {blocks.map((block, i) => {
          const isNewest = block.id === newestId;
          const sealed = Boolean(block.hash);
          return (
            <div key={block.id} className="relative pl-5">
              {i < blocks.length - 1 && (
                <span className="absolute left-[7px] top-5 bottom-[-4px] w-px bg-teal-300/15" />
              )}
              <span
                className={`absolute left-0 top-1.5 h-3.5 w-3.5 rounded-full border ${
                  block.status === "completed"
                    ? "border-teal-300/70 bg-teal-300/20"
                    : block.status === "failed"
                    ? "border-red-300/70 bg-red-300/20"
                    : "border-white/20 bg-black/40"
                } ${isNewest && isThinking ? "animate-pulse" : ""}`}
              />
              <button
                onClick={() => setOpenId(openId === block.id ? null : block.id)}
                className={`w-full text-left rounded-lg border px-2.5 py-2 mb-1.5 flex items-center justify-between gap-2 transition-colors ${
                  isNewest
                    ? "border-teal-300/25 bg-teal-300/[0.05]"
                    : "border-white/5 bg-black/20"
                }`}
              >
                <span className="flex items-center gap-1.5 min-w-0">
                  {isNewest && isThinking && (
                    <Sparkle className="h-3 w-3 text-teal-300/70 shrink-0 animate-pulse" />
                  )}
                  <span className="truncate text-[11px] text-white/75">{block.label}</span>
                </span>
                <span className="flex items-center gap-1.5 shrink-0">
                  <span className={`font-mono text-[9px] ${sealed ? "text-teal-200/50" : "text-white/20 italic"}`}>
                    {sealed ? shortHash(block.hash) : "unsealed"}
                  </span>
                  {openId === block.id ? (
                    <ChevronDown className="h-3 w-3 text-white/30" />
                  ) : (
                    <ChevronRight className="h-3 w-3 text-white/30" />
                  )}
                </span>
              </button>
              {openId === block.id && (
                <div className="mb-2 ml-4 rounded-lg border border-white/5 bg-black/30 px-2.5 py-2 text-[10px] text-white/50 font-mono space-y-1">
                  <div>status: {block.status}</div>
                  <div>entry_hash: {block.hash || "unsealed — not yet signed into the chain"}</div>
                </div>
              )}
            </div>
          );
        })}
      </div>

      <div className="mt-2 flex items-center gap-1.5 text-[9px] font-mono text-white/25">
        <ShieldCheck className="h-3 w-3" />
        <span>{isThinking ? "chain extending…" : "chain idle"} · Ed25519-signed, hash-linked</span>
      </div>
    </div>
  );
}
