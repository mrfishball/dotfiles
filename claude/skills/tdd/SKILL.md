---
name: tdd
description: Build a behavior change test-first with subagents - brief, failing tests, minimal code, refactor, independent evaluation - with frozen tests, stall detection, and escalation. Use when the user runs /tdd, or asks to build a feature or fix test-first. Add --independent-tests to have a separate agent write the tests.
---

# Test-driven build with subagents

You orchestrate; the agents build and judge. Subagents can't launch other subagents, so every handoff goes through you. Agents share context only through the run folder (RUN), never through paraphrase: pass them the RUN path and let them read.

`TR` below is `~/.claude/bin/tdd-run`.

## 0. Does this fit?

Use this for behavior changes with outcomes a test can observe. For trivial edits, config, or docs, say so and do the work directly.

## 1. Set up

1. `TR init <short-slug>` from inside the repo. It prints RUN.
2. Use the `Explore` agent to find: the code involved, existing tests and fixtures to reuse, the test framework, and the exact test command.

## 2. Brief

Fill every section of `RUN/brief.md`.
- **Acceptance criteria:** numbered and testable. If they're vague or missing, ask the user before going on. A thin brief is the main reason agents guess.
- **Test boundary:** the concrete public entry points tests may call.

Then run `TR brief-check RUN` and fix anything it reports.

## 3. Baseline

Run the test command from the brief once.
- If the command doesn't work, fix the brief.
- Record already-failing tests: `TR set RUN baseline_failures="<names or none>"`. They won't be blamed on this change.

## 4. Red

- **Default:** the `builder` agent in mode `red`.
- **With `--independent-tests`:** the `test-writer` agent.

Check `RUN/test-plan.md` for red evidence. Every new test must fail on an assertion or a not-implemented error, with no load errors. If the gate isn't met after 2 tries, stop and escalate.

Then freeze: `TR freeze RUN <test files listed under "Test files:">` and `TR set RUN phase=green round=1`.

## 5. Green

Run the `builder` agent in mode `green`, naming the latest `evaluation-N.md` from round 2 onward. Then:

1. **Disputes:** if progress.md has a new `DISPUTE`, judge it against the brief yourself.
   - If valid, fix the test, re-freeze, and continue.
   - A second dispute in the run, or one that needs a product decision, goes to the user.
2. **Frozen tests:** run `TR check-frozen RUN`. If tests changed without an accepted dispute, run `TR restore-tests RUN` and send the builder back.
3. **Progress:** `TR record RUN <passing> <total>`. If it exits 3 (stalled), stop and escalate.

## 6. Refactor

Once all tests are green:

1. The `refactorer` agent with pass `code`. Then `TR check-frozen RUN` must pass.
2. The `refactorer` agent with pass `tests`.

A refactor that restores its snapshot isn't a failure. Continue with the restored state.

## 7. Evaluate

Run the `evaluator` agent with RUN and N = the current round. It must not receive progress.md or your own commentary.

- **PASS:** finish.
- **FAIL:** if round < 3, run `TR set RUN round=<round+1>` and go back to step 5 with the evaluation. Otherwise, escalate.

## 8. Finish or escalate

`TR set RUN phase=done` (or `phase=escalated stop_reason="..."`). Then tell the user:
- each acceptance criterion and the test that covers it
- files changed
- the evaluator's verdict
- refactors applied or restored
- the RUN path

Offer `/commit`. Never commit or push on your own.

## Stop and escalate when

- the red gate fails twice
- a second dispute arises
- `TR record` reports a stall
- 3 rounds pass without a PASS
- an agent reports it is blocked

When you escalate, give the user the specific question or blocker, not a status dump.
