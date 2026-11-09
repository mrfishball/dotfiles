---
name: commit
description: Commit the current changes with a Conventional Commits message. Use when the user asks to commit, or runs /commit.
---

# Commit

1. Run `git status` and `git diff` (staged and unstaged). If there is nothing to commit, say so and stop.
2. Check `git log --oneline -15`. If the repo follows Conventional Commits, match its types and scopes. If it uses another convention, follow that instead and say so.
3. Stage: if files are already staged, commit only those. Otherwise stage the files that belong to the current task and list anything you left out. Never stage secrets, `.env` files, or large generated files.
4. Write the message:
   - Subject: `type(scope): summary`. Types: feat, fix, refactor, perf, test, docs, build, ci, chore, style. Imperative mood, 72 characters or fewer, no trailing period. Scope is optional.
   - Body: why the change was made, when that isn't obvious from the subject. Wrap at 72.
   - Breaking change: `!` after the type, plus a `BREAKING CHANGE:` footer.
   - Add any attribution lines the session requires.
5. Commit, then show `git log --oneline -1`. Do not push unless asked.
6. If a pre-commit hook fails, fix the cause and commit again. Never use `--no-verify` unless the user asks.
