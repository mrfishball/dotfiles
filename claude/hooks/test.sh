#!/bin/bash
# Exercise every hook against sample input in a throwaway sandbox.
# Usage: ~/dotfiles/claude/hooks/test.sh
set -u
# Git exports these to hooks; clear them so sandbox repos never see the outer repo.
unset GIT_DIR GIT_INDEX_FILE GIT_WORK_TREE GIT_PREFIX
HOOKS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="$HOOKS/../bin"
PY="/usr/bin/python3 -I"
SANDBOX="$(mktemp -d /tmp/claude-hook-tests.XXXXXX)"
trap 'rm -rf "$SANDBOX"' EXIT

export CLAUDE_LOG_DIR="$SANDBOX/logs" CLAUDE_TRASH_DIR="$SANDBOX/trash" CLAUDE_MEMORY_ROOT="$SANDBOX/home"
export CLAUDE_CLIENT_TERMS="$SANDBOX/terms.txt" CLAUDE_GATE_TEMP_ROOTS="/nonexistent" CLAUDE_MEMORY_PUSH=0
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
unset CLAUDE_HOOKS_OFF

PASS=0 FAIL=0
check() { # name, actual, expected-substring ("" means expect empty output)
    if { [ -z "$3" ] && [ -z "$2" ]; } || { [ -n "$3" ] && [[ "$2" == *"$3"* ]]; }; then
        PASS=$((PASS + 1))
    else
        FAIL=$((FAIL + 1)); printf 'FAIL %s\n  expected: %s\n  got: %s\n' "$1" "${3:-<nothing>}" "$2"
    fi
}
bash_input() { $PY -c 'import json,sys; print(json.dumps({"session_id":"s1","cwd":sys.argv[1],"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":sys.argv[2]}}))' "$1" "$2"; }
gate() { bash_input "$REPO" "$1" | $PY "$HOOKS/destructive_gate.py"; }

# Sandbox repo
REPO="$SANDBOX/repo"
mkdir -p "$REPO/src" "$REPO/node_modules/x" && cd "$REPO" && git init -q && echo a > src/a.txt && echo b > notes.txt
git add -A && git commit -qm init && git branch -M feat

echo "== destructive_gate"
check "rm tracked dir"         "$(gate 'rm -rf src')"                       '"deny"'
check "rm suggests quarantine" "$(gate 'rm -rf src')"                       'quarantine --session s1 src'
check "rm rebuildable"         "$(gate 'rm -rf node_modules')"              ''
check "rm missing path"        "$(gate 'rm -rf does-not-exist')"            ''
check "rm after &&"            "$(gate 'echo hi && rm notes.txt')"          '"deny"'
check "rm on next line"        "$(gate $'ls\nrm notes.txt')"                '"deny"'
check "rm via bash -c"         "$(gate 'bash -c "rm -rf src"')"             '"deny"'
check "find -delete"           "$(gate 'find . -name "*.txt" -delete')"     '"deny"'
check "xargs rm"               "$(gate 'ls | xargs rm')"                    '"deny"'
check "heredoc text ignored"   "$(gate $'git commit -F - <<\'EOF\'\nrm -rf / and drop table x\nEOF')" ''
check "reset --hard clean"     "$(gate 'git reset --hard HEAD')"            ''
echo change >> src/a.txt
check "reset --hard dirty"     "$(gate 'git reset --hard HEAD')"            'stash push'
check "git -C dirty"           "$(bash_input / "git -C $REPO checkout -- ." | $PY "$HOOKS/destructive_gate.py")" '"deny"'
check "cd then reset dirty"    "$(bash_input / "cd $REPO && git reset --hard" | $PY "$HOOKS/destructive_gate.py")" '"deny"'
check "restore --staged ok"    "$(gate 'git restore --staged src/a.txt')"   ''
git checkout -q -- .
check "git clean -fd"          "$(gate 'git clean -fd')"                    '"deny"'
check "git clean -n"           "$(gate 'git clean -nd')"                    ''
check "push plain"             "$(gate 'git push origin feat')"             ''
check "push --force"           "$(gate 'git push --force origin feat')"     'force-with-lease'
check "push -fu"               "$(gate 'git push -fu origin feat')"         '"deny"'
check "push lease own branch"  "$(gate 'git push --force-with-lease origin feat')" ''
check "push lease shared"      "$(gate 'git push --force-with-lease origin main')"  '"ask"'
check "push +refspec shared"   "$(gate 'git push --force-with-lease origin +HEAD:main')" '"ask"'
check "push delete"            "$(gate 'git push origin --delete old')"     '"ask"'
check "branch -D allowed"      "$(gate 'git branch -D old')"                ''
check "kubectl get"            "$(gate 'kubectl get pods -n x')"            ''
check "kubectl delete"         "$(gate 'kubectl delete pod x -n y')"        '"ask"'
check "helm uninstall"         "$(gate 'helm uninstall rel')"               '"ask"'
check "terraform plan"         "$(gate 'terraform plan')"                   ''
check "terraform apply"        "$(gate 'terraform apply -auto-approve')"    '"ask"'
check "psql drop"              "$(gate 'psql -c "DROP TABLE users"')"       '"ask"'
check "psql heredoc drop"      "$(gate $'psql <<SQL\ntruncate users;\nSQL')" '"ask"'
check "commit msg mentions drop" "$(gate 'git commit -m "drop table docs"')" ''
check "gradle clean"           "$(gate './gradlew clean build')"            ''
check "rm build dir (java)"    "$(mkdir -p build/classes && gate 'rm -rf build target')" ''
check "kill switch"            "$(bash_input "$REPO" 'rm -rf src' | CLAUDE_HOOKS_OFF=1 $PY "$HOOKS/destructive_gate.py")" ''

echo "== quarantine"
echo q > "$SANDBOX/qfile"
check "move"                   "$($PY "$BIN/quarantine" --session s1 "$SANDBOX/qfile")" 'Quarantined 1'
check "moved away"             "$([ -e "$SANDBOX/qfile" ] && echo still-there)" ''
check "list"                   "$($PY "$BIN/quarantine" --list)"            "$SANDBOX/qfile"
check "restore"                "$($PY "$BIN/quarantine" --restore s1)"      'restored'
check "back in place"          "$(cat "$SANDBOX/qfile")"                    'q'
check "purge"                  "$($PY "$BIN/quarantine" --purge 14)"        'Purged'

echo "== search_guard"
search() { $PY -c 'import json,sys; print(json.dumps({"tool_name":sys.argv[1],"tool_input":json.loads(sys.argv[2])}))' "$1" "$2" | $PY "$HOOKS/search_guard.py"; }
: > "$CLAUDE_CLIENT_TERMS"
check "empty list allows"      "$(search WebSearch '{"query":"acme latency"}')" ''
printf '# client terms\nAcme\nwidget-svc\n' > "$CLAUDE_CLIENT_TERMS"
check "search hit"             "$(search WebSearch '{"query":"ACME p99 latency"}')" '"deny"'
check "hyphenated term"        "$(search WebSearch '{"query":"widget-svc timeout"}')" '"deny"'
check "substring not a hit"    "$(search WebSearch '{"query":"acmetric tools"}')" ''
check "generic query"          "$(search WebSearch '{"query":"grpc retry backoff"}')" ''
check "fetch client domain ok" "$(search WebFetch '{"url":"https://acme.com/docs","prompt":"x"}')" ''
check "fetch query hit"        "$(search WebFetch '{"url":"https://example.com/search?q=acme+outage","prompt":"x"}')" '"deny"'

echo "== session_reminder"
mkdir -p "$CLAUDE_MEMORY_ROOT/memory"
LOGF="$CLAUDE_MEMORY_ROOT/memory/mistakes_log.md"
for i in $(seq 10 25); do echo "2026-10-$i | p | cat | x | y | no"; done > "$LOGF"
check "16 entries remind"      "$(echo '{}' | $PY "$HOOKS/session_reminder.py")" '16 unreviewed'
sed -i '' '1i\
Last review: 2026-10-20
' "$LOGF"
check "after review quiet"     "$(echo '{}' | $PY "$HOOKS/session_reminder.py")" ''

echo "== lint_reminder"
JAVA="$SANDBOX/java-svc"
mkdir -p "$JAVA" && cd "$JAVA" && git init -q && printf '<plugin><artifactId>spotless-maven-plugin</artifactId></plugin>\n' > pom.xml
lint() { $PY -c 'import json,sys; print(json.dumps({"cwd":sys.argv[1],"session_id":"s1"}))' "$1" | $PY "$HOOKS/lint_reminder.py"; }
check "java repo reminded"     "$(lint "$JAVA")"                            'spotless'
check "once a week"            "$(lint "$JAVA")"                            ''
rm "$CLAUDE_LOG_DIR/lint-reminder.json"
mkdir -p .claude && echo '{"hooks":{"Stop":[{"hooks":[]}]}}' > .claude/settings.local.json
check "has hook, quiet"        "$(lint "$JAVA")"                            ''
check "non-repo quiet"         "$(lint "$SANDBOX")"                         ''

echo "== activity_log + statusline + stats"
echo '{"hook_event_name":"PostToolUse","tool_name":"Bash","session_id":"s1","cwd":"/x/proj"}' | $PY "$HOOKS/activity_log.py"
check "logged tool call"       "$(cat "$CLAUDE_LOG_DIR"/activity-*.jsonl)"  '"tool": "Bash"'
check "no command logged"      "$(grep -c '"command"' "$CLAUDE_LOG_DIR"/activity-*.jsonl)" '0'
SL='{"session_id":"s1","model":{"display_name":"Opus"},"workspace":{"current_dir":"'"$REPO"'"},"context_window":{"used_percentage":42},"cost":{"total_cost_usd":1.5,"total_lines_added":3,"total_lines_removed":1}}'
check "statusline"             "$(echo "$SL" | $PY "$HOOKS/statusline.py")" 'ctx 42%'
check "snapshot written"       "$(cat "$CLAUDE_LOG_DIR/sessions/s1.json")"  '"cost_usd": 1.5'
check "stats"                  "$($PY "$BIN/claude-stats")"                 'Bash 1'

echo "== memory_reminder"
rm -rf "$CLAUDE_MEMORY_ROOT/memory"
for m in memory memory-client; do
    mkdir -p "$CLAUDE_MEMORY_ROOT/$m" && git -C "$CLAUDE_MEMORY_ROOT/$m" init -q
    echo x > "$CLAUDE_MEMORY_ROOT/$m/f.md" && git -C "$CLAUDE_MEMORY_ROOT/$m" add -A && git -C "$CLAUDE_MEMORY_ROOT/$m" commit -qm init
done
check "all clean, quiet"       "$(echo '{}' | $PY "$HOOKS/memory_reminder.py")" ''
echo y >> "$CLAUDE_MEMORY_ROOT/memory/f.md"; echo z > "$CLAUDE_MEMORY_ROOT/memory-client/new.md"
check "names dirty folders"    "$(echo '{}' | $PY "$HOOKS/memory_reminder.py")" 'memory (1 file), memory-client (1 file)'
check "nothing committed"      "$(git -C "$CLAUDE_MEMORY_ROOT/memory" log --oneline | wc -l | tr -d ' ')" '1'

echo "== tdd-run"
export CLAUDE_WORK_DIR="$SANDBOX/work"
TR="$PY $BIN/tdd-run"
TREPO="$SANDBOX/tdd-repo"
mkdir -p "$TREPO/src" "$TREPO/tests" && cd "$TREPO" && git init -q
echo base > src/app.txt && echo keep > src/other.txt && echo t0 > tests/test_a.txt && git add -A && git commit -qm base
RUN="$($TR init demo)"
check "init prints run"        "$RUN"                                       "$SANDBOX/work/tdd-repo/demo"
check "brief incomplete"       "$($TR brief-check "$RUN" 2>&1)"             'unfilled placeholders'
sed -i '' 's/<fill in:[^>]*>/filled/' "$RUN/brief.md"
check "approach unconfirmed"   "$($TR brief-check "$RUN" 2>&1)"             'approach not confirmed'
$TR set "$RUN" approach=confirmed
check "approach confirmed"     "$($TR brief-check "$RUN" 2>&1)"             'brief complete'
$TR set "$RUN" approach=pending
/usr/bin/python3 -I -c 'import sys; p=sys.argv[1]; t=open(p).read(); i=t.index("## Approach\n"); open(p,"w").write(t[:i]+"## Approach\nNot needed: one obvious shape\n")' "$RUN/brief.md"
check "approach not needed"    "$($TR brief-check "$RUN" 2>&1)"             'brief complete'
echo t1 > tests/test_a.txt
check "freeze"                 "$($TR freeze "$RUN" tests/test_a.txt)"      'froze 1'
check "frozen unchanged"       "$($TR check-frozen "$RUN")"                 'unchanged'
echo weakened > tests/test_a.txt
check "frozen changed"         "$($TR check-frozen "$RUN"; echo "exit=$?")" 'exit=1'
check "test-diff shows it"     "$($TR test-diff "$RUN")"                    '+weakened'
$TR restore-tests "$RUN" >/dev/null
check "restore-tests"          "$(cat tests/test_a.txt)"                    't1'
$TR record "$RUN" 2 5 >/dev/null; $TR record "$RUN" 3 5 >/dev/null
check "progress not stalled"   "$($TR record "$RUN" 4 5; echo "exit=$?")"  'exit=0'
$TR record "$RUN" 4 5 >/dev/null
check "stall detected"         "$($TR record "$RUN" 4 5; echo "exit=$?")"  'exit=3'
check "done is not a stall"    "$($TR record "$RUN" 5 5; echo "exit=$?")"  'exit=0'
echo built > src/app.txt && echo new > src/new.txt
SNAP="$($TR snapshot "$RUN")"
echo refactor-broke-it > src/app.txt && echo stray > src/stray.txt && echo touched > src/other.txt && rm tests/test_a.txt src/new.txt
check "restore"                "$($TR restore "$RUN" "$SNAP")"              'failed attempt saved'
check "modified file back"     "$(cat src/app.txt)"                         'built'
check "new file back"          "$(cat src/new.txt)"                         'new'
check "deleted test back"      "$(cat tests/test_a.txt)"                    't1'
check "base file reverted"     "$(cat src/other.txt)"                       'keep'
check "stray file removed"     "$([ -e src/stray.txt ] && echo present)"   ''
check "attempt kept"           "$(cat "$RUN"/attempts/*/src/stray.txt)"     'stray'
touch -t 202001010000 "$RUN/state.json"
check "purge old runs"         "$($TR purge 30)"                            'purged 1'

echo "== tdd-run worktrees"
WREPO="$SANDBOX/wt-repo"
mkdir -p "$WREPO/src/a" "$WREPO/src/b" && cd "$WREPO" && git init -q
echo a > src/a/core.txt && echo b > src/b/core.txt && git add -A && git commit -qm base
WRUN="$($TR init par)"
echo contract > src/iface.txt
WA="$($TR wt-add "$WRUN" a src/a/)"
check "worktree has contract"  "$(cat "$WA/src/iface.txt")"                 'contract'
check "main HEAD untouched"    "$(git log --oneline | wc -l | tr -d ' ')"   '1'
check "main index untouched"   "$(git diff --cached --name-only)"           ''
echo a2 > "$WA/src/a/core.txt" && echo new > "$WA/src/a/added.txt"
check "collect"                "$($TR wt-collect "$WRUN" a)"                'collected a: 2 file(s)'
check "change applied"         "$(cat src/a/core.txt)"                      'a2'
check "new file applied"       "$(cat src/a/added.txt)"                     'new'
check "worktree removed"       "$([ -e "$WA" ] && echo present)"            ''
check "branch removed"         "$(git branch --list 'tdd/*')"               ''
WB="$($TR wt-add "$WRUN" b src/b/)"
echo sneaky > "$WB/src/iface.txt"
check "outside owned refused"  "$($TR wt-collect "$WRUN" b; echo "exit=$?")" 'exit=4'
check "nothing applied"        "$(cat src/iface.txt)"                       'contract'
check "drop saves changes"     "$($TR wt-drop "$WRUN" b)"                   'changes saved'
check "dropped worktree gone"  "$([ -e "$WB" ] && echo present)"            ''
WB="$($TR wt-add "$WRUN" b src/b/)"
echo theirs > "$WB/src/b/core.txt" && echo ours > src/b/core.txt
check "conflict refused"       "$($TR wt-collect "$WRUN" b; echo "exit=$?")" 'exit=5'
check "main kept its change"   "$(cat src/b/core.txt)"                      'ours'
$TR wt-drop "$WRUN" b >/dev/null
cd "$SANDBOX"

echo "== no silent crashes"
check "no hook_error logged"   "$(cat "$CLAUDE_LOG_DIR"/activity-*.jsonl | grep -c hook_error)" '0'

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
