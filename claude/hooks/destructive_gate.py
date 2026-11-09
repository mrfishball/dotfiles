"""PreToolUse gate for destructive Bash commands.

Recoverable operations are redirected to a reversible form first: quarantine
instead of rm, stash before discarding changes, --force-with-lease instead of
--force. Operations nothing local can undo (shared-branch rewrites, remote
deletes, databases, clusters, infrastructure) prompt the user.

A safety net, not a sandbox: deletes inside scripts or Makefiles are not seen.
"""
import glob
import os
import re
import shlex
import subprocess
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.realpath(__file__)))
from _common import decide, disabled, log, read_input  # noqa: E402

NAME = "destructive_gate"
QUARANTINE = "~/.claude/bin/quarantine"

REBUILDABLE = {
    "node_modules", "build", "dist", "target", ".venv", "venv", "__pycache__",
    ".pytest_cache", ".mypy_cache", ".ruff_cache", ".gradle", ".next", ".turbo",
    "coverage", ".tox",
}
TEMP_ROOTS = [os.path.normpath(p) for p in (
    os.environ["CLAUDE_GATE_TEMP_ROOTS"].split(":") if "CLAUDE_GATE_TEMP_ROOTS" in os.environ else
    ("/tmp", "/private/tmp", "/var/folders", "/private/var/folders", os.environ.get("TMPDIR") or "/tmp")
)]
SHARED_BRANCH = re.compile(r"^(main|master|develop|development|trunk|release/.+|hotfix/.+)$")
DB_CLIENTS = {"psql", "mysql", "mariadb", "sqlite3", "duckdb", "mongosh", "mongo",
              "clickhouse-client", "snowsql", "bq", "cqlsh"}
DESTRUCTIVE_SQL = re.compile(r"\b(drop\s+(table|database|schema|view|index)|truncate)\b", re.I)
WRAPPERS = {"sudo", "command", "nohup", "time", "exec", "nice", "env"}
SHELLS = {"bash", "sh", "zsh"}
SEPARATORS = set(";&|()")
REDIRECTS = set("<>")
HEREDOC = re.compile(r"<<-?\s*(['\"]?)(\w+)\1([^\n]*)\n(.*?)\n[ \t]*\2[ \t]*(?=\n|$)", re.S)


def newlines_to_semicolons(s):
    """Treat unquoted newlines as command separators so each line is its own segment."""
    out, quote, escaped = [], None, False
    for ch in s:
        if escaped:
            escaped = False
        elif ch == "\\" and quote != "'":
            escaped = True
        elif quote:
            if ch == quote:
                quote = None
        elif ch in "'\"":
            quote = ch
        elif ch == "\n":
            out.append(" ; ")
            continue
        out.append(ch)
    return "".join(out)


def segments(cmd):
    """Split a command line into argv lists, one per simple command."""
    lex = shlex.shlex(newlines_to_semicolons(cmd), posix=True, punctuation_chars=";&|()<>")
    lex.whitespace_split = True
    lex.commenters = ""
    try:
        tokens = list(lex)
    except ValueError:
        tokens = cmd.split()
    segs, cur, skip_next = [], [], False
    for tok in tokens:
        if skip_next:
            skip_next = False
        elif tok and set(tok) <= SEPARATORS:
            segs.append(cur)
            cur = []
        elif tok and set(tok) <= REDIRECTS | {"&"}:
            skip_next = True
        else:
            cur.append(tok)
    segs.append(cur)
    return [s for s in segs if s]


def unwrap(argv):
    """Strip env assignments and wrappers like sudo or xargs. Returns (argv, via_xargs)."""
    via_xargs = False
    while argv:
        head = os.path.basename(argv[0].strip("`$"))
        if re.match(r"^\w+=", argv[0]):
            argv = argv[1:]
        elif head in WRAPPERS:
            argv = argv[1:]
            while argv and (argv[0].startswith("-") or re.match(r"^\w+=", argv[0])):
                argv = argv[1:]
        elif head == "xargs":
            via_xargs = True
            argv = argv[1:]
            while argv and argv[0].startswith("-"):
                takes_value = argv[0] in ("-I", "-n", "-P", "-L", "-d", "-s", "-E")
                argv = argv[2:] if takes_value else argv[1:]
        else:
            break
    return argv, via_xargs


def resolve(base, path):
    path = os.path.expanduser(path)
    return os.path.normpath(path if os.path.isabs(path) else os.path.join(base, path))


def disposable(path):
    norm = os.path.normpath(os.path.abspath(path))
    if any(norm == root or norm.startswith(root + os.sep) for root in TEMP_ROOTS):
        return True
    return any(part in REBUILDABLE for part in norm.split(os.sep))


def safe_to_delete(target, cwd):
    if any(c in target for c in "$`"):
        return False
    path = resolve(cwd, target)
    matches = glob.glob(path) if glob.has_magic(path) else ([path] if os.path.lexists(path) else [])
    return all(disposable(m) for m in matches)


def git(d, *args):
    try:
        r = subprocess.run(["git", "-C", d] + list(args), capture_output=True, text=True, timeout=3)
        return r.stdout.strip() if r.returncode == 0 else None
    except (OSError, subprocess.SubprocessError):
        return None


def quarantine_msg(sid, paths):
    listed = " ".join(shlex.quote(p) for p in paths) if paths else "<paths>"
    return (
        "Permanent delete blocked. Move the files to quarantine instead so they can be restored:\n"
        f"  {QUARANTINE} --session {sid} {listed}\n"
        "Rebuildable output (node_modules, build, dist, target, .venv, caches) and temp paths "
        "can still be removed with rm."
    )


def check_rm(args, cwd, sid, via_xargs):
    if via_xargs:
        return "deny", ("rm via xargs deletes paths that can't be checked in advance. List them first, "
                        "then: " + quarantine_msg(sid, []))
    targets, end = [], False
    for a in args:
        if not end and a == "--":
            end = True
        elif not end and a.startswith("-") and a != "-":
            continue
        else:
            targets.append(a)
    at_risk = [t for t in targets if not safe_to_delete(t, cwd)]
    return ("deny", quarantine_msg(sid, at_risk)) if at_risk else None


def check_find(args, sid):
    execs_rm = any(a in ("-exec", "-execdir", "-ok") and i + 1 < len(args)
                   and os.path.basename(args[i + 1]) == "rm" for i, a in enumerate(args))
    if "-delete" in args or execs_rm:
        return "deny", ("find -delete / -exec rm deletes permanently. Run the same find with -print "
                        "to list matches, then: " + quarantine_msg(sid, []))
    return None


def short_flag(a, letter):
    return bool(re.match(r"^-[a-zA-Z]+$", a)) and letter in a


def check_git(args, cwd, sid, data):
    d, i = cwd, 0
    while i < len(args) and args[i].startswith("-"):
        if args[i] == "-C" and i + 1 < len(args):
            d = resolve(d, args[i + 1])
            i += 2
        elif args[i] in ("-c", "--git-dir", "--work-tree", "--namespace") and i + 1 < len(args):
            i += 2
        else:
            i += 1
    if i >= len(args):
        return None
    sub, rest = args[i], args[i + 1:]

    discards = (
        (sub == "reset" and "--hard" in rest)
        or (sub == "checkout" and ("--" in rest or "." in rest or "-f" in rest or "--force" in rest))
        or (sub == "restore" and not ({"--staged", "-S"} & set(rest) and not {"--worktree", "-W"} & set(rest)))
        or (sub == "switch" and ({"--discard-changes", "-f", "--force"} & set(rest)))
    )
    if discards:
        if git(d, "status", "--porcelain", "--untracked-files=no"):
            return "deny", (f"`git {sub}` would discard uncommitted changes in {d}. Save them first:\n"
                            f'  git -C {shlex.quote(d)} stash push -m "before git {sub}"\n'
                            "(restore with `git stash pop`), then retry.")
        return None

    if sub == "clean":
        force = any(a == "--force" or short_flag(a, "f") for a in rest)
        dry = any(a == "--dry-run" or short_flag(a, "n") for a in rest)
        if force and not dry:
            return "deny", ("git clean deletes untracked files permanently. Run it with -n instead of -f "
                            "to list them, then: " + quarantine_msg(sid, []))
        return None

    if sub == "stash" and rest[:1] == ["clear"]:
        return "ask", "git stash clear drops every stash at once, including saved work."

    if sub == "branch" and ("-D" in rest or ("--delete" in rest and {"-f", "--force"} & set(rest))):
        log("guard", data, hook=NAME, decision="allow-recoverable", kind="git branch -D")
        return None

    if sub == "push":
        flags = [a for a in rest if a.startswith("-")]
        refspecs = [a for a in rest if not a.startswith("-")][1:]
        lease = any(a.startswith("--force-with-lease") for a in flags)
        force = any(a == "--force" or short_flag(a, "f") for a in flags) or any(r.startswith("+") for r in refspecs)
        deleting = "--delete" in flags or any(short_flag(f, "d") for f in flags) \
            or any(r.startswith(":") for r in refspecs)
        if "--mirror" in flags:
            return "ask", "git push --mirror overwrites every ref on the remote."
        if not (force or lease or deleting):
            return None
        if force and not lease:
            return "deny", ("Plain --force can overwrite remote commits you haven't fetched. Use "
                            "--force-with-lease instead (your reflog keeps the old remote state), then retry.")
        branches = [r.lstrip("+").split(":")[-1].replace("refs/heads/", "") for r in refspecs] \
            or [git(d, "branch", "--show-current") or ""]
        if deleting:
            return "ask", f"Deletes remote branch {', '.join(b for b in branches if b)}. Others may depend on it."
        shared = [b for b in branches if SHARED_BRANCH.match(b)]
        if shared:
            return "ask", f"Force-pushes shared branch {', '.join(shared)}, rewriting history others depend on."
        log("guard", data, hook=NAME, decision="allow-recoverable", kind="git push --force-with-lease")
    return None


def check_segment(argv, cwd, sid, data, heredocs):
    argv, via_xargs = unwrap(argv)
    if not argv:
        return None
    name, args = os.path.basename(argv[0].strip("`$")), argv[1:]
    if name in SHELLS and "-c" in args:
        idx = args.index("-c")
        return classify(args[idx + 1], cwd, sid, data) if idx + 1 < len(args) else None
    if name == "rm":
        return check_rm(args, cwd, sid, via_xargs)
    if name == "find":
        return check_find(args, sid)
    if name == "git":
        return check_git(args, cwd, sid, data)
    if name in ("kubectl", "oc") and {"delete", "drain"} & set(args):
        return "ask", "kubectl delete/drain removes or evicts cluster resources."
    if name == "helm" and {"uninstall", "delete", "del", "un"} & set(args[:2]):
        return "ask", "helm uninstall removes a release and its resources."
    if name in ("terraform", "tofu", "terragrunt") and {"apply", "destroy"} & set(args):
        return "ask", "terraform apply/destroy changes real infrastructure."
    if name in DB_CLIENTS and DESTRUCTIVE_SQL.search(" ".join(args + heredocs)):
        return "ask", "Runs DROP or TRUNCATE against a database."
    return None


def classify(cmd, cwd, sid, data):
    heredocs = [m.group(4) for m in HEREDOC.finditer(cmd)]
    cmd = HEREDOC.sub(lambda m: m.group(3), cmd)
    results = []
    for argv in segments(cmd):
        if os.path.basename(argv[0]) == "cd" and len(argv) > 1:
            cwd = resolve(cwd, argv[1])
            continue
        r = check_segment(argv, cwd, sid, data, heredocs)
        if r:
            results.append(r)
    for decision in ("deny", "ask"):
        reasons = [reason for d, reason in results if d == decision]
        if reasons:
            return decision, "\n\n".join(reasons)
    return None


def main():
    if disabled(NAME):
        return
    data = read_input()
    cmd = (data.get("tool_input") or {}).get("command") or ""
    result = classify(cmd, data.get("cwd") or os.getcwd(), data.get("session_id") or "manual", data)
    if result:
        decision, reason = result
        log("guard", data, hook=NAME, decision=decision)
        decide(decision, ("Destructive command: " if decision == "ask" else "") + reason)


if __name__ == "__main__":
    try:
        main()
    except Exception as e:  # a broken hook must never block work
        log("hook_error", {}, hook=NAME, error=type(e).__name__)
