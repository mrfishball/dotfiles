"""SessionStart: remind to set up format/lint hooks in repos that have the tooling.

Detects the repo's own formatters and linters (root and one level down) and
checks whether its .claude/settings*.json already has PostToolUse or Stop hooks.
Reminds at most once a week per repo. To silence a repo for good, add its path
to ~/.claude/private/lint-reminder-ignore.txt.
"""
import glob
import json
import os
import re
import subprocess
import sys
import time

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.realpath(__file__)))
from _common import CLAUDE_DIR, LOG_DIR, disabled, log, read_input  # noqa: E402

NAME = "lint_reminder"
IGNORE_FILE = os.path.join(CLAUDE_DIR, "private", "lint-reminder-ignore.txt")
STATE_FILE = os.path.join(LOG_DIR, "lint-reminder.json")
INTERVAL = 7 * 24 * 3600

# (tool label, glob relative to a project dir, optional regex the file must contain)
SIGNALS = [
    ("eslint", "eslint.config.*", None), ("eslint", ".eslintrc*", None),
    ("prettier", ".prettierrc*", None), ("prettier", "prettier.config.*", None),
    ("biome", "biome.json*", None),
    ("ruff", "ruff.toml", None), ("ruff", "pyproject.toml", r"\[tool\.ruff"),
    ("black", "pyproject.toml", r"\[tool\.black"), ("mypy", "pyproject.toml", r"\[tool\.mypy"),
    ("mypy", "mypy.ini", None), ("flake8", ".flake8", None),
    ("pre-commit", ".pre-commit-config.yaml", None),
    ("spotless", "build.gradle*", r"spotless"), ("ktlint", "build.gradle*", r"ktlint"),
    ("checkstyle", "build.gradle*", r"checkstyle"), ("spotless", "pom.xml", r"spotless"),
    ("checkstyle", "pom.xml", r"checkstyle"), ("pmd", "build.gradle*", r"\bpmd\b"), ("pmd", "pom.xml", r"\bpmd\b"),
    ("google-java-format", "build.gradle*", r"google-java-format|googleJavaFormat"),
    ("google-java-format", "pom.xml", r"google-java-format|fmt-maven-plugin"),
    ("gofmt/go vet", "go.mod", None), ("golangci-lint", ".golangci.y*ml", None),
    ("rustfmt/clippy", "Cargo.toml", None),
    ("make lint/format", "Makefile", r"(?m)^(lint|format|fmt)\s*:"),
    ("mise lint/format", "mise.toml", r"(?m)^\[tasks\.\"?(lint|format|fmt)"),
    ("mise lint/format", ".mise.toml", r"(?m)^\[tasks\.\"?(lint|format|fmt)"),
]


def repo_root(cwd):
    try:
        r = subprocess.run(["git", "-C", cwd, "rev-parse", "--show-toplevel"],
                           capture_output=True, text=True, timeout=2)
        return r.stdout.strip() if r.returncode == 0 else None
    except (OSError, subprocess.SubprocessError):
        return None


def file_matches(path, pattern):
    if pattern is None:
        return True
    try:
        with open(path, errors="ignore") as f:
            return re.search(pattern, f.read(200_000)) is not None
    except OSError:
        return False


def package_json_tools(path):
    try:
        with open(path) as f:
            pkg = json.load(f)
    except (OSError, ValueError):
        return set()
    deps = set(pkg.get("devDependencies") or {}) | set(pkg.get("dependencies") or {})
    found = {t for t in ("eslint", "prettier", "@biomejs/biome") if t in deps}
    found |= {f"npm run {s}" for s in (pkg.get("scripts") or {}) if re.match(r"^(lint|format|fmt)(:|$)", s)}
    return {t.replace("@biomejs/", "") for t in found}


def detect_tools(root):
    dirs = [root] + [d for d in glob.glob(os.path.join(root, "*")) if os.path.isdir(d)
                     and os.path.basename(d) not in ("node_modules", ".git", "vendor", "dist", "build")]
    tools = set()
    for d in dirs:
        for label, pattern, must_contain in SIGNALS:
            if any(file_matches(p, must_contain) for p in glob.glob(os.path.join(d, pattern))):
                tools.add(label)
        tools |= package_json_tools(os.path.join(d, "package.json"))
    return sorted(tools)


def has_quality_hooks(root):
    for name in ("settings.json", "settings.local.json"):
        try:
            with open(os.path.join(root, ".claude", name)) as f:
                hooks = json.load(f).get("hooks") or {}
        except (OSError, ValueError):
            continue
        if hooks.get("PostToolUse") or hooks.get("Stop"):
            return True
    return False


def ignored(root):
    try:
        with open(IGNORE_FILE) as f:
            return any(os.path.expanduser(line.strip()).rstrip("/") == root for line in f if line.strip())
    except OSError:
        return False


def main():
    if disabled(NAME):
        return
    data = read_input()
    root = repo_root(data.get("cwd") or os.getcwd())
    if not root or ignored(root) or has_quality_hooks(root):
        return
    try:
        with open(STATE_FILE) as f:
            state = json.load(f)
    except (OSError, ValueError):
        state = {}
    if time.time() - state.get(root, 0) < INTERVAL:
        return
    tools = detect_tools(root)
    if not tools:
        return
    state[root] = time.time()
    os.makedirs(LOG_DIR, exist_ok=True)
    with open(STATE_FILE, "w") as f:
        json.dump(state, f)
    log("reminder", data, hook=NAME, tools=tools)
    print(f"This repo has format/lint tooling ({', '.join(tools)}) but no Claude format/lint hook. "
          "Offer the user a per-repo Stop hook that runs these tools on files edited in the response, "
          "and ask whether it belongs in .claude/settings.local.json (personal) or .claude/settings.json "
          f"(shared with the team). If they decline, add {root} to {IGNORE_FILE} so this stops.")


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        log("hook_error", {}, hook=NAME, error=type(e).__name__)
