"""SessionStart: one-line nudge when the mistakes logs are due for review.

Counts entries dated after each log's `Last review: YYYY-MM-DD` line (all
entries if the line is missing) across ~/.claude/memory*/mistakes_log*.md.
Prints nothing below the threshold (CLAUDE_MISTAKES_REVIEW_AT, default 15).
"""
import glob
import os
import re
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.realpath(__file__)))
from _common import CLAUDE_DIR, disabled, log, read_input  # noqa: E402

NAME = "session_reminder"
ENTRY_DATE = re.compile(r"(?m)^\s*(?:[-*]\s*)?(?:\*\*)?(\d{4}-\d{2}-\d{2})\b")
LAST_REVIEW = re.compile(r"Last review:\s*(\d{4}-\d{2}-\d{2})")


def unreviewed(path):
    with open(path) as f:
        text = f.read()
    m = LAST_REVIEW.search(text)
    since = m.group(1) if m else ""
    return sum(1 for d in ENTRY_DATE.findall(text) if d > since)


def main():
    if disabled(NAME):
        return
    data = read_input()
    root = os.environ.get("CLAUDE_MEMORY_ROOT") or CLAUDE_DIR
    threshold = int(os.environ.get("CLAUDE_MISTAKES_REVIEW_AT") or 15)
    total = sum(unreviewed(p) for p in glob.glob(os.path.join(root, "memory*", "mistakes_log*.md")))
    if total >= threshold:
        log("reminder", data, hook=NAME, unreviewed=total)
        print(f"Mistakes log: {total} unreviewed entries (review threshold {threshold}). "
              "Tell the user a review is due (process: ~/.claude/memory/feedback_mistake_review_loop.md).")


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        log("hook_error", {}, hook=NAME, error=type(e).__name__)
