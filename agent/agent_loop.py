"""
agent_loop.py — real agentic tool-use loop.

The model gets real tools via Groq function-calling, including the ability
to propose brand-new tools for itself (test-gated, via self_extend.py).
Every tool call is executed for real via ActionEngine's honest dispatch
handlers, results are fed back to the model, and the loop repeats until
the model stops calling tools or max_steps is hit.

Every real tool result is signed via proofchain if a signed_log path is given.
Session state persists across separate invocations via --resume.
"""
import os
import sys
import json as json_module
import time
import asyncio
import re
import logging
import tempfile

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.append(os.path.expanduser('~/.omega/lib'))

from api.groq_client import chat_completion
from agent.core.action_engine import Action, ActionNode, ActionExecutor, ActionValidator, SideEffectAnalyzer
from agent.self_extend import propose_tool
from lib.omega_proof import sign_event
from agent.decision_provenance import build_decision_provenance
from agent.web_search_tool import web_search

logger = logging.getLogger("OmegaAgentLoop")
RUNTIME_LOG_DIR = os.path.expanduser("~/.omega/logs")
os.makedirs(RUNTIME_LOG_DIR, exist_ok=True)


def _safe_sign_event(signed_log, event_type, data):
    if not signed_log:
        return
    try:
        sign_event(signed_log, event_type=event_type, data=data)
    except Exception as exc:
        # Evidence misconfiguration must never take down an otherwise valid chat.
        # The event remains observable in the transcript and the warning is
        # available in the service log for operational repair.
        logger.warning("proof event skipped for %s: %s", event_type, exc)


TOOLS = [
    {
        "type": "function",
        "function": {
            "name": "read_file",
            "description": "Read the contents of a file at the given path.",
            "parameters": {
                "type": "object",
                "properties": {"path": {"type": "string", "description": "File path to read"}},
                "required": ["path"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "write_file",
            "description": "Write content to a file at the given path, creating directories if needed.",
            "parameters": {
                "type": "object",
                "properties": {
                    "path": {"type": "string"},
                    "content": {"type": "string"},
                },
                "required": ["path", "content"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "edit_file",
            "description": "Replace an exact unique text match in a file with new text (like find-and-replace).",
            "parameters": {
                "type": "object",
                "properties": {
                    "path": {"type": "string"},
                    "old_str": {"type": "string", "description": "Exact text to find, must be unique in file"},
                    "new_str": {"type": "string", "description": "Text to replace it with"},
                },
                "required": ["path", "old_str", "new_str"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "list_dir",
            "description": "List files and directories at the given path.",
            "parameters": {"type": "object", "properties": {"path": {"type": "string"}}, "required": ["path"]},
        },
    },
    {
        "type": "function",
        "function": {
            "name": "run_bash",
            "description": "Run a shell command and return its stdout/stderr/exit code.",
            "parameters": {
                "type": "object",
                "properties": {"command": {"type": "string"}},
                "required": ["command"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "scan_iot_devices",
            "description": "Scan the local network for connected devices (IP/MAC) and report the agent's own environment (battery, location). Logs a local, gitignored history entry for family-safety tracking.",
            "parameters": {
                "type": "object",
                "properties": {},
                "required": [],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "compile_code",
            "description": "Check a Python file compiles cleanly (syntax check).",
            "parameters": {
                "type": "object",
                "properties": {"path": {"type": "string"}},
                "required": ["path"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "git_status",
            "description": "Show git status for the repo at the given directory path.",
            "parameters": {"type": "object", "properties": {"path": {"type": "string"}}, "required": ["path"]},
        },
    },
    {
        "type": "function",
        "function": {
            "name": "git_diff",
            "description": "Show git diff of unstaged changes for the repo at the given directory path.",
            "parameters": {"type": "object", "properties": {"path": {"type": "string"}}, "required": ["path"]},
        },
    },
    {
        "type": "function",
        "function": {
            "name": "git_commit",
            "description": "Stage all changes and commit with the given message, in the repo at the given directory path.",
            "parameters": {
                "type": "object",
                "properties": {"path": {"type": "string"}, "message": {"type": "string"}},
                "required": ["path", "message"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "grep_search",
            "description": "Search for a text/regex pattern across .py/.js/.jsx files under a directory.",
            "parameters": {
                "type": "object",
                "properties": {"pattern": {"type": "string"}, "path": {"type": "string"}},
                "required": ["pattern"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "glob_find",
            "description": "Find files matching a glob pattern recursively under a directory.",
            "parameters": {
                "type": "object",
                "properties": {"pattern": {"type": "string"}, "path": {"type": "string"}},
                "required": ["pattern"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "write_todos",
            "description": "Save/update your task checklist for a multi-step job.",
            "parameters": {
                "type": "object",
                "properties": {"todos": {"type": "array", "items": {"type": "string"}}},
                "required": ["todos"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "read_todos",
            "description": "Read your current task checklist.",
            "parameters": {"type": "object", "properties": {}},
        },
    },
    {
        "type": "function",
        "function": {
            "name": "web_fetch",
            "description": "Fetch the content of a URL.",
            "parameters": {"type": "object", "properties": {"url": {"type": "string"}}, "required": ["url"]},
        },
    },
    {
        "type": "function",
        "function": {
            "name": "run_tests",
            "description": "Run pytest against a file or directory and report real pass/fail results.",
            "parameters": {"type": "object", "properties": {"path": {"type": "string"}}, "required": ["path"]},
        },
    },
    {
        "type": "function",
        "function": {
            "name": "git_log",
            "description": "Show recent commit history.",
            "parameters": {
                "type": "object",
                "properties": {"path": {"type": "string"}, "count": {"type": "integer"}},
                "required": ["path"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "word_count",
            "description": "Count words in a file.",
            "parameters": {"type": "object", "properties": {"path": {"type": "string"}}, "required": ["path"]},
        },
    },
    {
        "type": "function",
        "function": {
            "name": "memory_search",
            "description": "Search your own cryptographically verified history (past agent decisions, tool executions, and self-extension attempts) for a keyword. Use this to check what you've already done or learned before, instead of assuming.",
            "parameters": {
                "type": "object",
                "properties": {"query": {"type": "string"}},
                "required": ["query"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "propose_new_tool",
            "description": (
                "Propose a brand-new tool for yourself when none of your existing tools can "
                "accomplish something you need. You must provide: the handler code (a Python "
                "'elif name == \"toolname\": ...' block matching the existing dispatch pattern, "
                "returning (bool success, dict output)), and a pytest test proving it works. "
                "Your proposal is only merged into your real capabilities if it compiles, your "
                "own test passes, AND the full existing regression suite still passes afterward. "
                "If any check fails, the attempt is rejected and logged, and you keep your "
                "current tools unchanged."
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "handler_name": {"type": "string"},
                    "handler_code": {"type": "string"},
                    "test_code": {"type": "string"},
                    "description": {"type": "string"},
                },
                "required": ["handler_name", "handler_code", "test_code"],
            },
        },
    },
]

SYSTEM_PROMPT = (
    "You are Omega, an agentic coding assistant with real tool access. "
    "You can read files, write files, run shell commands, and check code compiles. "
    "Use only tools listed in the current tool schema; never invent a tool name. "
    "For environment, runtime, phone, server, or IoT questions, call "
    "inspect_local_environment immediately as the first and only tool; do not "
    "use list_dir, read_file, glob_find, grep_search, or run_bash for a "
    "local-environment request. Never probe /opt/render, /, or any path outside "
    "the approved Omega workspace. The inspection tool performs local-only "
    "metadata collection and never performs network probing. "
    "Use tools to actually accomplish the task; never claim something is done "
    "unless a tool result confirmed it. When the task is complete, reply with "
    "a final summary and make no further tool calls."
)
async def _execute_tool_call(executor, tool_call):
    """Take one model tool_call, run it for real, return the real result dict."""
    name = tool_call["function"]["name"]
    try:
        args = json_module.loads(tool_call["function"]["arguments"])
    except json_module.JSONDecodeError as e:
        return {"error": f"Model sent malformed tool arguments: {e}"}

    if name == "scan_iot_devices":
        from agent.environment import get_environment_context, check_for_new_devices
        import os, json, time
        env = get_environment_context()
        scan = check_for_new_devices()
        # local-only, gitignored history — never pushed to the repo
        hist_path = os.path.expanduser("~/.omega/location_history.jsonl")
        os.makedirs(os.path.dirname(hist_path), exist_ok=True)
        with open(hist_path, "a") as f:
            f.write(json_module.dumps({"ts": time.time(), "environment": env, "scan": scan}) + "\n")
        return {"environment": env, "network_scan": scan}

    if name == "propose_new_tool":
        # Not a normal dispatch action — runs the full test-gated self-extension
        # pipeline instead, synchronously (it's already fast: compile + pytest).
        result = propose_tool(
            handler_name=args.get("handler_name", "unnamed_tool"),
            handler_code=args.get("handler_code", ""),
            test_code=args.get("test_code", ""),
            description=args.get("description", ""),
        )
        return result

    action = Action(name=name, target=args.get("path"))
    node = ActionNode(action=action, parameters=args)
    result = await executor._execute_with_retry(node, {})

    return {
        "success": result.success,
        "output": result.output,
        "error": result.error_message,
    }


def _verify_grounding(final_content, transcript):
    """
    Re-checks the model's final narrative against real transcript data.
    Returns (grounded: bool, violations: list[str]).

    Two checks, both driven by actual tool results — never by trusting
    the model's own account of what it did:
      1. Claimed file writes with no matching write_file tool_call in
         the transcript (fabricated "I saved/created/wrote X" claims).
      2. Any tool call that failed but whose failure isn't reflected
         anywhere in the final narrative at all (silent failure hidden
         from the user).
    """
    violations = []

    executed_writes = set()
    failed_steps = []
    for entry in transcript:
        if entry.get("role") != "tool":
            continue
        result = entry.get("result", {})
        output = result.get("output", {}) if isinstance(result, dict) else {}
        cmd = output.get("command", "") if isinstance(output, dict) else ""

        tool_name = entry.get("tool_name") or entry.get("name")
        if tool_name == "write_file" or "write_file" in cmd:
            target = entry.get("target") or output.get("path")
            if target:
                executed_writes.add(target)

        is_failure = (
            result.get("success") is False
            or result.get("accepted") is False
        )
        if is_failure:
            failed_steps.append(entry.get("step"))

    claim_re = re.compile(
        r"(?:wrote|saved|created|updated) (?:the )?file[:\s]+([^\s,\.]+)",
        re.IGNORECASE,
    )
    for claimed_path in claim_re.findall(final_content or ""):
        if claimed_path not in executed_writes:
            violations.append(
                f"claimed to write \"{claimed_path}\" but no matching write_file "
                "tool call exists in this session's transcript"
            )

    if failed_steps and "SYSTEM-VERIFIED FAILURES" not in (final_content or ""):
        violations.append(
            f"tool call(s) at step(s) {failed_steps} failed but the final "
            "narrative does not acknowledge any failure"
        )

    return (len(violations) == 0, violations)


SESSION_PATH = os.path.expanduser("~/.omega/logs/agent_session.json")
os.makedirs(os.path.dirname(SESSION_PATH), exist_ok=True)


def load_session():
    if os.path.exists(SESSION_PATH):
        with open(SESSION_PATH) as f:
            return json_module.load(f)
    return None


def save_session(messages):
    os.makedirs(os.path.dirname(SESSION_PATH), exist_ok=True)
    directory = os.path.dirname(SESSION_PATH)
    temporary = None
    try:
        fd, temporary = tempfile.mkstemp(prefix=".agent-session-", dir=directory, text=True)
        with os.fdopen(fd, "w") as f:
            json_module.dump({"messages": messages, "saved_at": time.time()}, f, indent=2, default=str)
            f.flush()
            os.fsync(f.fileno())
        os.replace(temporary, SESSION_PATH)
    except Exception as exc:
        if temporary:
            try:
                os.unlink(temporary)
            except OSError:
                pass
        logger.warning("session persistence skipped: %s", exc)


def run_agent_task(task_description, max_steps=10, signed_log=None, cwd_hint=None, resume=False, on_step=None, require_plan=False, image_inputs=None):
    """
    Runs the real tool-use loop synchronously (wraps async internals).
    Returns the full transcript: list of {step, role, content/tool_calls/tool_result}.
    """
    validator = ActionValidator()
    analyzer = SideEffectAnalyzer()
    executor = ActionExecutor(validator, analyzer)

    system = SYSTEM_PROMPT
    try:
        from agent.environment import get_environment_context
        env_ctx = get_environment_context()
        system += f" Current physical environment: {env_ctx}"
    except Exception as _env_err:
        logger.warning("environment context unavailable: %s", _env_err)
    if cwd_hint:
        system += f" The current working directory is {cwd_hint}."

    prior = load_session() if resume else None
    image_inputs = image_inputs or []
    if image_inputs:
        content_parts = [{"type": "text", "text": task_description}]
        content_parts.extend(
            {"type": "image_url", "image_url": {"url": item["dataUrl"]}}
            for item in image_inputs
        )
        user_content = content_parts
    else:
        user_content = task_description

    if prior and prior.get("messages"):
        messages = prior["messages"]
        messages.append({"role": "user", "content": user_content})
    else:
        messages = [
            {"role": "system", "content": system},
            {"role": "user", "content": user_content},
        ]

    transcript = []
    final_content = ""
    provenance_parent_id = None
    available_tool_names = [item["function"]["name"] for item in TOOLS]
    loop = asyncio.new_event_loop()

    try:
        for step in range(max_steps):
            MAX_RECENT_MESSAGES = 6
            trimmed = messages[:2] + messages[2:][-MAX_RECENT_MESSAGES:]
            effort = "default"

            message = chat_completion(
                trimmed,
                tools=TOOLS,
                reasoning_effort=effort,
                max_tokens=1024,
                return_message=True,
            )

            tool_calls = message.get("tool_calls")
            grounded, violations = True, []

            if not tool_calls:
                final_content = message.get("content", "")
                if not isinstance(final_content, str) or not final_content.strip():
                    final_content = (
                        "Omega completed the observable agent loop, but the model returned "
                        "no final narrative. Review the live workspace transcript for the "
                        "verified steps and retry the request once the provider responds normally."
                    )
                narrative_text = final_content  # pristine copy, before any system-appended blocks

                # Ground-truth failure check. The model's own summary is not
                # trusted on its own - every prior tool call in this session
                # is re-inspected here, and any real failure gets appended
                # verbatim regardless of what the model claimed. This is the
                # only place fabricated "success" reporting gets caught,
                # since it runs on the raw transcript data, not the model's
                # narration of it.
                failed_calls = []
                for entry in transcript:
                    if entry.get("role") != "tool":
                        continue
                    result = entry.get("result", {})
                    output = result.get("output", {}) if isinstance(result, dict) else {}
                    is_failure = (
                        result.get("success") is False
                        or result.get("accepted") is False
                    )
                    if is_failure:
                        err = (
                            output.get("error")
                            if isinstance(output, dict) and output.get("error")
                            else result.get("reason", "unspecified failure")
                        )
                        failed_calls.append(f"- step {entry.get('step')}: {err}")

                if failed_calls:
                    final_content += (
                        "\n\n[SYSTEM-VERIFIED FAILURES - do not treat prior "
                        "narration as authoritative on these points]\n"
                        + "\n".join(failed_calls)
                    )

                # Ground any counting/verification commands the same way -
                # ensures claimed numbers in the final response actually
                # came from a real tool call, not the model's guess.
                verified_data = []
                for entry in transcript:
                    if entry.get("role") != "tool":
                        continue
                    result = entry.get("result", {})
                    output = result.get("output", {}) if isinstance(result, dict) else {}
                    cmd = output.get("command", "") if isinstance(output, dict) else ""
                    if "wc -l" in cmd or ("find" in cmd and "-type f" in cmd):
                        stdout = output.get("stdout", "").strip()
                        if stdout:
                            verified_data.append(f"- step {entry.get('step')}: `{cmd}` -> {stdout}")

                if verified_data:
                    final_content += (
                        "\n\n[SYSTEM-VERIFIED DATA - use these exact figures, "
                        "do not restate different numbers]\n"
                        + "\n".join(verified_data)
                    )

                    # Parse real "name: number" pairs out of the actual
                    # verified stdout, then check whether the model's own
                    # narrative claimed a *different* number for the same
                    # name. This catches fabrication even when a real tool
                    # result was available and simply ignored/overridden.
                    verified_numbers = {}
                    pair_re = re.compile(r"([A-Za-z0-9_\-\.]+):\s*(\d+)")
                    for entry in transcript:
                        if entry.get("role") != "tool":
                            continue
                        result = entry.get("result", {})
                        output = result.get("output", {}) if isinstance(result, dict) else {}
                        cmd = output.get("command", "") if isinstance(output, dict) else ""
                        if "wc -l" in cmd or ("find" in cmd and "-type f" in cmd):
                            stdout = output.get("stdout", "") if isinstance(output, dict) else ""
                            for name, num in pair_re.findall(stdout):
                                verified_numbers[name] = num

                    contradictions = []
                    for name, real_num in verified_numbers.items():
                        for claimed_name, claimed_num in pair_re.findall(narrative_text):
                            if claimed_name == name and claimed_num != real_num:
                                contradictions.append(
                                    f"- \"{name}\": model said {claimed_num}, "
                                    f"verified tool output says {real_num}"
                                )

                    if contradictions:
                        final_content = (
                            "[SYSTEM WARNING: the response below contains numbers "
                            "that contradict verified tool output. Do not trust the "
                            "narrative's figures - use SYSTEM-VERIFIED DATA below "
                            "instead.]\n"
                            + "\n".join(contradictions)
                            + "\n\n"
                            + final_content
                        )

                final_entry = {"step": step, "role": "assistant", "content": final_content, "final": True}
                transcript.append(final_entry)
                if on_step:
                    try:
                        on_step(final_entry)
                    except Exception:
                        pass
                grounded, violations = _verify_grounding(final_content, transcript)
                if not grounded and violations:
                    final_content += (
                        "\n\n[SYSTEM WARNING: the following claims could not be "
                        "verified against this session's actual tool results and "
                        "should not be trusted]\n"
                        + "\n".join(f"- {v}" for v in violations)
                    )
                _safe_sign_event(signed_log, event_type="grounding_check", data={
                    "step": step, "grounded": grounded, "violations": violations,
                })
                _safe_sign_event(signed_log, event_type="agent_final", data={"step": step, "content": final_content[:1000]})
                break

            messages.append(message)
            decision_records = []
            for tc in tool_calls:
                tool_name = tc["function"]["name"]
                tool_args = tc["function"].get("arguments", {})
                decision = build_decision_provenance(
                    action=tool_name,
                    arguments=tool_args,
                    step=step,
                    available_alternatives=available_tool_names,
                    parent_id=provenance_parent_id,
                    observed_context=transcript[-6:],
                )
                decision_records.append(decision)
                provenance_parent_id = decision["decision_id"]
                _safe_sign_event(signed_log, event_type="decision_provenance", data=decision)
            transcript.append({"step": step, "role": "assistant", "tool_calls": tool_calls, "decision_provenance": decision_records})
            if on_step:
                try:
                    on_step(transcript[-1])
                except Exception:
                    pass

            for tc_index, tc in enumerate(tool_calls):
                result = loop.run_until_complete(_execute_tool_call(executor, tc))

                _safe_sign_event(signed_log, event_type="tool_call", data={
                    "step": step,
                    "tool": tc["function"]["name"],
                    "arguments": tc["function"]["arguments"],
                    "result": result,
                })

                decision = decision_records[tc_index]
                transcript.append({
                    "step": step,
                    "role": "tool",
                    "tool_call_id": tc["id"],
                    "result": result,
                    "decision_provenance": decision,
                })
                if on_step:
                    try:
                        on_step(transcript[-1])
                    except Exception:
                        pass

                # Cap tool-result size before it enters history. This is
                # byte-based, not tied to today's file/repo counts, so it
                # keeps working as the empire grows and a single tool call
                # (e.g. reading a large source file) can't blow the token
                # budget on its own. Full result still goes in `transcript`
                # (line above) and signed_log - only what feeds back into
                # the model's context gets capped.
                MAX_TOOL_RESULT_CHARS = 3000
                result_json = json_module.dumps(result, default=str)
                if len(result_json) > MAX_TOOL_RESULT_CHARS:
                    result_json = (
                        result_json[:MAX_TOOL_RESULT_CHARS]
                        + f"... [truncated, {len(result_json)} chars total - "
                        + "full result available in transcript/signed_log]"
                    )

                messages.append({
                    "role": "tool",
                    "tool_call_id": tc["id"],
                    "name": tc["function"]["name"],
                    "content": result_json,
                })

                # A local environment inspection is complete and bounded.
                if (
                    tc["function"]["name"] in {"inspect_local_environment", "scan_iot_devices"}
                    and isinstance(result, dict)
                    and result.get("success") is not False
                ):
                    inspection = result.get("output", result)
                    forced_final = {
                        "step": step,
                        "role": "assistant",
                        "content": "LOCAL_INSPECTION_OK\n" + json_module.dumps(inspection, sort_keys=True, default=str),
                        "final": True,
                        "completion_status": "local_inspection_complete",
                    }
                    transcript.append(forced_final)
                    if on_step:
                        try:
                            on_step(forced_final)
                        except Exception:
                            pass
                    return transcript
        else:
            final_entry = {
                "step": max_steps,
                "role": "assistant",
                "content": f"Omega reached the execution limit of {max_steps} steps before the model produced a final response. The observable transcript above is complete; continue from the last verified step to resume.",
                "final": True,
                "completion_status": "max_steps",
            }
            transcript.append(final_entry)
            if on_step:
                try:
                    on_step(final_entry)
                except Exception:
                    pass

    finally:
        loop.close()
        try:
            save_session(messages)
        except Exception as exc:
            logger.warning("session cleanup skipped: %s", exc)

    return transcript


if __name__ == "__main__":
    import sys as _sys
    args = _sys.argv[1:]
    resume = "--resume" in args
    if resume:
        args.remove("--resume")
    task = " ".join(args) or "List the files in the current directory using run_bash, then summarize what you see."
    log_path = os.path.expanduser("~/.omega/logs/agent_loop_signed.log")
    result = run_agent_task(task, signed_log=log_path, resume=resume)
    for entry in result:
        print(json_module.dumps(entry, indent=2, default=str))
