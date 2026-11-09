#!/bin/bash
# SessionEnd: commit changed memory folders; push the global one if it's ahead.
#
# ~/.claude/memory          commit + push (client-neutral, branch is pinned to `global`)
# ~/.claude/memory-*/       commit only; pushing client memory stays manual
# Does nothing when a folder has no changes. Push runs in the background with
# SSH batch mode so a session never hangs on it.

[ "$CLAUDE_HOOKS_OFF" = 1 ] || [ "$CLAUDE_HOOK_OFF_MEMORY_AUTOCOMMIT" = 1 ] && exit 0
cat >/dev/null

ROOT="${CLAUDE_MEMORY_ROOT:-$HOME/.claude}"
LOG_DIR="${CLAUDE_LOG_DIR:-$HOME/.claude/logs}"
LOG="$LOG_DIR/activity-$(date +%Y-%m).jsonl"
mkdir -p "$LOG_DIR"

log() {
    printf '{"ts":"%s","event":"memory_autocommit","repo":"%s","result":"%s"}\n' \
        "$(date +%Y-%m-%dT%H:%M:%S%z)" "$(basename "$1")" "$2" >> "$LOG"
}

commit_if_changed() {
    local dir="$1" changes
    [ -d "$dir/.git" ] || return
    changes=$(git -C "$dir" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    [ "$changes" -gt 0 ] || return
    if git -C "$dir" add -A && git -C "$dir" commit -q -m "Auto: session end $(date +%F) ($changes files changed)"; then
        log "$dir" committed
    else
        log "$dir" commit-failed
    fi
}

for dir in "$ROOT"/memory "$ROOT"/memory-*/; do
    commit_if_changed "${dir%/}"
done

GLOBAL="$ROOT/memory"
if [ -d "$GLOBAL/.git" ] && [ "${CLAUDE_MEMORY_PUSH:-1}" = 1 ]; then
    ahead=$(git -C "$GLOBAL" rev-list --count '@{u}..HEAD' 2>/dev/null || echo 0)
    if [ "$ahead" -gt 0 ]; then
        (
            export GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND="ssh -o BatchMode=yes -o ConnectTimeout=10"
            if git -C "$GLOBAL" push -q >/dev/null 2>&1; then log "$GLOBAL" pushed; else log "$GLOBAL" push-failed; fi
        ) &
        disown
    fi
fi
exit 0
