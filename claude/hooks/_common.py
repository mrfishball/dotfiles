"""Shared helpers for Claude Code hooks: kill switches, input, activity log."""
import json
import os
import sys
import time

CLAUDE_DIR = os.path.expanduser("~/.claude")
LOG_DIR = os.environ.get("CLAUDE_LOG_DIR") or os.path.join(CLAUDE_DIR, "logs")


def disabled(name):
    """CLAUDE_HOOKS_OFF=1 turns every hook off; CLAUDE_HOOK_OFF_<NAME>=1 turns off one."""
    if os.environ.get("CLAUDE_HOOKS_OFF") == "1":
        return True
    return os.environ.get("CLAUDE_HOOK_OFF_" + name.upper()) == "1"


def read_input():
    try:
        return json.load(sys.stdin)
    except Exception:
        return {}


def project(data):
    cwd = data.get("cwd") or os.getcwd()
    return os.path.basename(cwd.rstrip("/")) or "/"


def log(event, data, **fields):
    """Append one line to the monthly activity log. Never records prompts or tool inputs."""
    entry = {
        "ts": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
        "event": event,
        "session": data.get("session_id", ""),
        "project": project(data),
    }
    entry.update(fields)
    try:
        os.makedirs(LOG_DIR, exist_ok=True)
        path = os.path.join(LOG_DIR, time.strftime("activity-%Y-%m.jsonl"))
        with open(path, "a") as f:
            f.write(json.dumps(entry) + "\n")
    except OSError:
        pass


def decide(decision, reason):
    """Emit a PreToolUse permission decision: allow, deny, or ask."""
    print(json.dumps({"hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": decision,
        "permissionDecisionReason": reason,
    }}))
