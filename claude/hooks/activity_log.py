"""Activity logger for session and tool events.

Records event, tool name, success, session and project folder. Never records
prompts, commands, tool inputs or outputs. Read it with ~/.claude/bin/claude-stats.
"""
import os
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.realpath(__file__)))
from _common import disabled, log, read_input  # noqa: E402

NAME = "activity_log"


def main():
    if disabled(NAME):
        return
    data = read_input()
    event = data.get("hook_event_name") or "unknown"
    fields = {}
    if event in ("PostToolUse", "PostToolUseFailure"):
        fields = {"tool": data.get("tool_name"), "ok": event == "PostToolUse"}
    elif event == "SessionStart":
        fields = {"source": data.get("source")}
    elif event == "SessionEnd":
        fields = {"reason": data.get("reason")}
    log(event, data, **fields)


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        log("hook_error", {}, hook=NAME, error=type(e).__name__)
