"""Fail-closed pre-execution safety gate for observable Omega actions.
Creator attribution: Thomas Lee Harvey.
"""
from __future__ import annotations
import hashlib
import json
import os
import re
import time
from dataclasses import dataclass, asdict, field
from typing import Any, Iterable

SECRET_RE = re.compile(r"(?i)(api[_-]?key|token|secret|password|private[_-]?key|authorization)\s*[:=]")
DANGEROUS_RE = re.compile(r"(?i)(rm\s+-rf|mkfs|dd\s+if=|shutdown|reboot|curl[^\n|]*\|\s*(sh|bash)|chmod\s+777)")

def stable_hash(value: Any) -> str:
    return hashlib.sha256(json.dumps(value, sort_keys=True, default=str, separators=(",", ":")).encode()).hexdigest()

@dataclass(frozen=True)
class ActionProposal:
    action: str
    parameters: dict[str, Any] = field(default_factory=dict)
    target: str | None = None
    capability: str | None = None
    mutation: bool = False
    rollback: str | None = None
    acceptance_tests: tuple[str, ...] = ()
    expected_diff_hash: str | None = None
    parent_provenance_id: str | None = None
    def canonical(self): return asdict(self)

@dataclass(frozen=True)
class CouncilDecision:
    decision_id: str
    proposal_hash: str
    approved: bool
    findings: tuple[dict[str, Any], ...]
    created_at: float
    previous_hash: str | None = None
    def receipt(self):
        value = asdict(self)
        value["findings"] = list(self.findings)
        value["receipt_hash"] = stable_hash(value)
        return value

class ShadowCouncil:
    def __init__(self, *, allowed_roots: Iterable[str] = (), capabilities: Iterable[str] = (), previous_hash: str | None = None):
        self.allowed_roots = tuple(allowed_roots)
        self.capabilities = set(capabilities)
        self.previous_hash = previous_hash
    def review(self, proposal: ActionProposal) -> CouncilDecision:
        findings = []
        serialized = json.dumps(proposal.canonical(), sort_keys=True, default=str)
        if SECRET_RE.search(serialized):
            findings.append({"severity":"hard","code":"SECRET_LIKE_INPUT","message":"Secret-like material detected."})
        if proposal.action == "run_bash":
            command = str(proposal.parameters.get("command", ""))
            if not command.strip(): findings.append({"severity":"hard","code":"EMPTY_COMMAND","message":"Empty command."})
            if DANGEROUS_RE.search(command): findings.append({"severity":"hard","code":"DANGEROUS_COMMAND","message":"Dangerous command pattern."})
        if proposal.capability and self.capabilities and proposal.capability not in self.capabilities:
            findings.append({"severity":"hard","code":"UNKNOWN_CAPABILITY","message":"Capability is not registered."})
        if proposal.mutation and not proposal.rollback:
            findings.append({"severity":"hard","code":"NO_ROLLBACK","message":"Mutation lacks rollback."})
        if proposal.target and self.allowed_roots:
            target = os.path.realpath(os.path.abspath(os.path.expanduser(proposal.target)))
            roots = [os.path.realpath(os.path.abspath(os.path.expanduser(x))) for x in self.allowed_roots]
            if not any(target == r or target.startswith(r + os.sep) for r in roots):
                findings.append({"severity":"hard","code":"TARGET_OUTSIDE_ROOT","message":"Target outside approved roots."})
        approved = not any(x["severity"] == "hard" for x in findings)
        decision = CouncilDecision(stable_hash({"proposal":proposal.canonical(),"time":time.time_ns()})[:24], stable_hash(proposal.canonical()), approved, tuple(findings), time.time(), self.previous_hash)
        self.previous_hash = decision.receipt()["receipt_hash"]
        return decision

def append_receipt(path: str, decision: CouncilDecision):
    os.makedirs(os.path.dirname(os.path.abspath(os.path.expanduser(path))), exist_ok=True)
    with open(os.path.expanduser(path), "a", encoding="utf-8") as handle:
        handle.write(json.dumps(decision.receipt(), sort_keys=True) + "\n")
    return decision.receipt()
