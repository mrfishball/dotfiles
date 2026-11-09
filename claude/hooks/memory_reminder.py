"""SessionStart: remind when memory folders have uncommitted changes.

Checks every git-tracked ~/.claude/memory*/ folder. Prints nothing when all
are clean. Committing and pushing stay manual.
"""
import glob
import os
import subprocess
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.realpath(__file__)))
from _common import CLAUDE_DIR, disabled, log, read_input  # noqa: E402

NAME = "memory_reminder"


def uncommitted(path):
    try:
        r = subprocess.run(["git", "-C", path, "status", "--porcelain"], capture_output=True, text=True, timeout=3)
        return len(r.stdout.splitlines()) if r.returncode == 0 else 0
    except (OSError, subprocess.SubprocessError):
        return 0


def main():
    if disabled(NAME):
        return
    data = read_input()
    root = os.environ.get("CLAUDE_MEMORY_ROOT") or CLAUDE_DIR
    dirty = []
    for path in sorted(glob.glob(os.path.join(root, "memory*"))):
        if os.path.isdir(os.path.join(path, ".git")):
            n = uncommitted(path)
            if n:
                dirty.append(f"{os.path.basename(path)} ({n} file{'s' if n > 1 else ''})")
    if dirty:
        log("reminder", data, hook=NAME, folders=len(dirty))
        print(f"Memory folders with uncommitted changes: {', '.join(dirty)}. "
              "Mention this to the user; commit or push only if they ask.")


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        log("hook_error", {}, hook=NAME, error=type(e).__name__)
