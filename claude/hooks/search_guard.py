"""PreToolUse guard: block outbound searches that contain client terms.

Terms live in ~/.claude/private/client-terms.txt (local only, one per line,
# for comments). An empty or missing file disables the check.
WebFetch is checked on the URL's query and fragment only, so public docs on a
client's domain can still be fetched.
"""
import os
import re
import sys
from urllib.parse import unquote_plus, urlparse

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.realpath(__file__)))
from _common import CLAUDE_DIR, decide, disabled, log, read_input  # noqa: E402

NAME = "search_guard"
TERMS_FILE = os.environ.get("CLAUDE_CLIENT_TERMS") or os.path.join(CLAUDE_DIR, "private", "client-terms.txt")


def load_terms():
    try:
        with open(TERMS_FILE) as f:
            return [line.strip() for line in f if line.strip() and not line.lstrip().startswith("#")]
    except OSError:
        return []


def strings(value):
    if isinstance(value, str):
        yield value
    elif isinstance(value, dict):
        for v in value.values():
            yield from strings(v)
    elif isinstance(value, list):
        for v in value:
            yield from strings(v)


def main():
    if disabled(NAME):
        return
    terms = load_terms()
    if not terms:
        return
    data = read_input()
    tool_input = data.get("tool_input") or {}
    if data.get("tool_name") == "WebFetch":
        url = urlparse(tool_input.get("url") or "")
        texts = [unquote_plus(url.query), unquote_plus(url.fragment)]
    else:
        texts = list(strings(tool_input))
    pattern = re.compile(r"(?<!\w)(" + "|".join(re.escape(t) for t in terms) + r")(?!\w)", re.I)
    for text in texts:
        hit = pattern.search(text)
        if hit:
            log("guard", data, hook=NAME, decision="deny", tool=data.get("tool_name"))
            decide("deny", f"Outbound query contains the client term '{hit.group(1)}'. "
                           "Rephrase it generically, without client or internal service names, then retry.")
            return


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        log("hook_error", {}, hook=NAME, error=type(e).__name__)
