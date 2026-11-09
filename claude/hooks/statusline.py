"""Status line: model · project (branch) · context % · session cost · lines changed.

Also saves a per-session snapshot so claude-stats can report cost, since hooks
don't receive cost data. Cost is a list-price estimate, not billed spend.
"""
import json
import os
import subprocess
import sys
import time

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.realpath(__file__)))
from _common import LOG_DIR, disabled, read_input  # noqa: E402

NAME = "statusline"
RED, YELLOW, DIM, RESET = "\033[31m", "\033[33m", "\033[2m", "\033[0m"


def branch(cwd):
    try:
        r = subprocess.run(["git", "-C", cwd, "branch", "--show-current"], capture_output=True,
                           text=True, timeout=0.5, env=dict(os.environ, GIT_OPTIONAL_LOCKS="0"))
        return r.stdout.strip()
    except (OSError, subprocess.SubprocessError):
        return ""


def snapshot(data, proj, model, pct, usd, added, removed):
    sid = data.get("session_id")
    if not sid:
        return
    d = os.path.join(LOG_DIR, "sessions")
    os.makedirs(d, exist_ok=True)
    tmp = os.path.join(d, f".{sid}.tmp")
    with open(tmp, "w") as f:
        json.dump({"session": sid, "project": proj, "model": model, "cost_usd": usd, "context_pct": pct,
                   "lines_added": added, "lines_removed": removed,
                   "updated": time.strftime("%Y-%m-%dT%H:%M:%S%z")}, f)
    os.replace(tmp, os.path.join(d, f"{sid}.json"))


def main():
    data = read_input()
    model = (data.get("model") or {}).get("display_name") or "?"
    cwd = (data.get("workspace") or {}).get("current_dir") or data.get("cwd") or os.getcwd()
    proj = os.path.basename(cwd.rstrip("/")) or "/"
    pct = (data.get("context_window") or {}).get("used_percentage")
    cost = data.get("cost") or {}
    usd = cost.get("total_cost_usd") or 0
    added, removed = cost.get("total_lines_added") or 0, cost.get("total_lines_removed") or 0

    br = branch(cwd)
    parts = [model, f"{proj} ({br})" if br else proj]
    if pct is not None:
        color = RED if pct >= 80 else YELLOW if pct >= 60 else ""
        parts.append(f"{color}ctx {pct:.0f}%{RESET if color else ''}")
    parts += [f"${usd:.2f}", f"+{added}/−{removed}"]
    print(f" {DIM}·{RESET} ".join(parts))

    if not disabled(NAME):
        try:
            snapshot(data, proj, model, pct, usd, added, removed)
        except OSError:
            pass


if __name__ == "__main__":
    main()
