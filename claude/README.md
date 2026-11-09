# Claude Code harness

My user-level Claude Code setup: instructions, hooks, status line, and helper tools. Everything here applies to every project. Client-specific context lives in each client folder's own `CLAUDE.md` and memory, never here.

**Design rule:** prose for judgment, hooks for invariants. `CLAUDE.md` and memory shape how Claude thinks. Hooks run outside the model and fire every time, so they back up the few rules that are costly to break. Keep hooks small, owned, and tested; add one only when a prose rule has proven insufficient or the stakes justify it.

## Layout

```
claude/
  CLAUDE.md          global instructions (working guidelines, verify-before-stating, mistakes loop)
  settings.json      hook wiring, status line, memory directory
  hooks/             one script per hook, plus shared helpers and tests
  bin/               command-line tools (quarantine, claude-stats)
  skills/            user-level skills, one folder each
  agents/            user-level subagents
  README.md          this file
.githooks/pre-commit  repo guard: client-term leak check + hook tests
```

`install.sh` links `CLAUDE.md`, `settings.json`, `hooks/`, `bin/` and `agents/` into `~/.claude/`, and each skill folder into `~/.claude/skills/` (that folder also holds org-synced skills, so it isn't linked whole). It links individual entries, not the whole `~/.claude` folder, which also holds sessions and auth. It also sets `core.hooksPath` so the pre-commit guard runs.

**This repo is public.** Everything under `claude/` must stay generic: no client names, services, code, or details. The pre-commit guard enforces this against your client-terms list.

Local-only files, never committed:

| Path | Purpose |
|---|---|
| `~/.claude/private/client-terms.txt` | Terms the search guard blocks, one per line |
| `~/.claude/private/lint-reminder-ignore.txt` | Repo paths the lint reminder should skip |
| `~/.claude/logs/` | Activity log, session snapshots, reminder state |
| `~/.claude/trash/` | Quarantined files, purged after 14 days |

## Hooks

Hooks only affect commands Claude runs through its tools. Commands you type in your own terminal are never gated.

| Hook | Event | What it does |
|---|---|---|
| `destructive_gate.py` | PreToolUse (Bash) | Makes destructive commands reversible first, or asks you. See below. |
| `search_guard.py` | PreToolUse (WebSearch, WebFetch, O'Reilly search) | Blocks outbound queries that contain a client term. WebFetch is checked on the URL's query and fragment only, so public docs on a client domain still load. Does nothing while the terms file is empty. |
| `session_reminder.py` | SessionStart | One line when the mistakes logs have 15+ entries dated after their `Last review:` line. |
| `lint_reminder.py` | SessionStart | In a repo that has format/lint tooling but no Claude PostToolUse or Stop hook, suggests setting one up. At most once a week per repo. |
| `memory_reminder.py` | SessionStart | Names any `~/.claude/memory*` folder with uncommitted changes. Never commits or pushes. |
| `activity_log.py` | PostToolUse, PostToolUseFailure, SessionStart, Stop, SessionEnd | Appends event, tool name, success, session and project folder to `~/.claude/logs/activity-YYYY-MM.jsonl`. Never records prompts, commands or tool inputs. |
| `statusline.py` | Status line | `model · project (branch) · ctx % · $cost · +added/−removed`. Context turns yellow at 60% and red at 80%. Saves a per-session snapshot so `claude-stats` can report cost. |

### Destructive gate

| Command | Behavior |
|---|---|
| `rm`, `find -delete`, `xargs rm`, `git clean -f` | Blocked, with the `quarantine` command to run instead. Paths that don't exist, temp paths (`/tmp`, `/var/folders`) and rebuildable output (`node_modules`, `build`, `dist`, `target`, `.venv`, `.gradle`, caches) are allowed. |
| `git reset --hard`, `git checkout -- …`, `git restore`, `git switch --discard-changes` | Blocked only when tracked files have uncommitted changes, with a `git stash push` command to run first. Allowed on a clean tree. |
| `git push --force` | Blocked; use `--force-with-lease`. |
| `git push --force-with-lease` | Allowed on your own branches. Asks you for shared branches (`main`, `master`, `develop`, `trunk`, `release/*`, `hotfix/*`). |
| `git push --delete`, `git push --mirror`, `git stash clear` | Asks you. |
| `kubectl delete/drain`, `helm uninstall`, `terraform apply/destroy`, `DROP`/`TRUNCATE` via a DB client | Asks you. |
| `git branch -D` | Allowed (recoverable from the reflog) and logged. |

It parses `&&`, `;`, pipes, new lines, `bash -c`, `sudo`/`env` wrappers, `cd`, and `git -C`. Heredoc bodies are ignored except as SQL input to a DB client. It is a safety net, not a sandbox: deletes inside scripts or Makefile targets are not seen.

## Tools

**`~/.claude/bin/quarantine`**: reversible delete.

```sh
quarantine [--session ID] PATH...   # move aside to ~/.claude/trash/<date>/<session>/<batch>/<original path>
quarantine --list [--days N]        # recent batches
quarantine --restore ID             # put back a batch, or a whole session
quarantine --purge DAYS             # runs automatically at session end with 14
```

**`~/.claude/bin/claude-stats [--days N]`**: summary of sessions, tool calls and failures, projects, guard decisions, reminders, and estimated cost. Cost is a list-price estimate, not billed spend.

## Kill switches

Set before starting `claude`:

```sh
CLAUDE_HOOKS_OFF=1 claude                     # all hooks
CLAUDE_HOOK_OFF_DESTRUCTIVE_GATE=1 claude     # one hook (name in upper case)
```

Hooks fail open: an unexpected error is logged as `hook_error` and never blocks work. `claude-stats` lists hook errors when there are any.

## Testing

```sh
~/dotfiles/claude/hooks/test.sh
```

Runs every hook against sample input in a throwaway sandbox, including a check that no hook crashed silently. Run it after any change to `hooks/` or `bin/`.

To see what the gate would do with one command, without running it:

```sh
gate() { /usr/bin/python3 -I -c 'import json,sys,os; print(json.dumps({"session_id":"manual","cwd":os.getcwd(),"tool_input":{"command":sys.argv[1]}}))' "$1" | CLAUDE_LOG_DIR=/tmp/gate-log /usr/bin/python3 -I ~/.claude/hooks/destructive_gate.py; }
gate 'git push --force origin main'   # empty output means allowed
```

## Skills

Invoke with `/<name>` or let Claude pick them up from context.

| Skill | What it does |
|---|---|
| `commit` | Commits current changes with a Conventional Commits message, matching the repo's existing convention. Never pushes or skips hooks unless asked. |
| `write-prd` | Drafts a PRD after 3 to 7 clarifying questions. Saves to `tasks/NNNN-prd-<name>.md`. Doesn't implement. |
| `generate-tasks` | Turns a PRD into parent tasks, then, after you reply "Go", sub-tasks that each end with a verify step. |
| `process-tasks` | Works through a task list one sub-task at a time, pausing for approval. Runs the test suite after each parent task. |

## Subagents

| Agent | What it does |
|---|---|
| `verifier` | Read-only fact checker. Takes a numbered list of claims about current code or config and returns each as confirmed, contradicted, or unverifiable, with file:line evidence. Marks unsourced rationale as NOT RECORDED. `CLAUDE.md` tells Claude to use it when an answer rests on several claims from memory, docs, or names. |

## Pre-commit guard

`.githooks/pre-commit` runs on every dotfiles commit:

1. Blocks staged additions that contain any term in `~/.claude/private/client-terms.txt`.
2. Runs `claude/hooks/test.sh` when `hooks/`, `bin/`, or `settings.json` change, and blocks the commit if a test fails. Hooks fail open at runtime, so this is what stops a broken hook from shipping.

## Adding a hook

1. One script per hook in `hooks/`, run with `/usr/bin/python3 -I`. The system Python avoids per-repo version managers (asdf, mise), and `-I` keeps a repo's files from being imported.
2. Import helpers from `_common.py`: `disabled(NAME)` for the kill switch, `read_input()`, `log()`, and `decide()` for PreToolUse decisions.
3. Wrap `main()` so exceptions are logged and the hook exits cleanly.
4. Never log prompts, commands, file contents or client names.
5. Wire it in `settings.json` with a timeout, add cases to `test.sh`, and add a row to the table above.

## Planned

- More subagent workflows
- Context and model tuning once `claude-stats` has a week of data
- MCP and tool-list audit (`/context` in a typical session)
- Per-repo format/typecheck Stop hooks, prompted by the lint reminder
- Config protection for lint and CI configs in team repos
