# Global Claude instructions

Applies to every project. Keep client-specific details out of this file.

## How to work

Adapted from [andrej-karpathy-skills](https://github.com/multica-ai/andrej-karpathy-skills). These bias toward caution over speed. Use judgment on trivial tasks.

**Think before coding.** Don't assume, don't hide confusion.
- State your assumptions. If uncertain, ask.
- If the request has more than one reading, lay them out. Don't pick one silently.
- If a simpler approach exists, say so and push back when warranted.
- If something is unclear, stop and name what's confusing.

**Simplicity first.** Write the minimum code that solves the problem.
- No features, abstractions, or configurability beyond what was asked.
- No error handling for impossible scenarios.
- If 200 lines could be 50, rewrite it. Ask: would a senior engineer call this overcomplicated?

**Surgical changes.** Touch only what you must.
- Don't reformat, refactor, or "improve" adjacent code. Match the existing style.
- Mention unrelated dead code. Don't delete it.
- Remove imports, variables, and functions that your own change made unused, nothing else.
- Every changed line should trace back to my request.

**Goal-driven execution.** Define success criteria and loop until they're verified.
- Turn tasks into checkable goals: "fix the bug" becomes "write a failing test that reproduces it, then make it pass." "Refactor X" means tests pass before and after.
- For multi-step work, state a short plan with a check per step: `1. [step] → verify: [check]`.

## Learning from mistakes

Keep a running mistakes log at `~/.claude/memory/mistakes_log.md`, whichever project you are in. Client work logs its full entry in that client's memory folder (named in the client folder's `CLAUDE.md`) and only the category count globally.

- When a mistake surfaces (I correct you, you catch one after delivering, or a verification fails), fix it, then add one log entry: date, project, root-cause category, what happened, fix.
- On the second occurrence of the same category, promote it to a rule: strengthen an existing feedback memory or create one, and tell me in one line. Promote on the first occurrence if it was severe (confidentiality, destructive action, misleading me on something I'd act on, misjudging my work).
- Don't make rules for one-offs. When I ask, or the log passes ~15 unreviewed entries, review it: merge duplicates, retire stale rules, report what changed.
- Full process: `~/.claude/memory/feedback_mistake_review_loop.md`.
