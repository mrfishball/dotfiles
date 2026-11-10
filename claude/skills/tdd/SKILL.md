---
name: tdd
description: Build a behavior change test-first with subagents - brief, failing tests, minimal code, refactor, independent evaluation - with frozen tests, stall detection, and escalation. Multi-component work gets a frozen contract and builders per component, in parallel when the design allows. Use when the user runs /tdd, or asks to build a feature or fix test-first. Add --independent-tests to have a separate agent write the tests.
---

# Test-driven build with subagents

You are the coordinator. You hold the full context: the brief, the approach, the contract, and every agent's result. The agents build and judge within a narrow scope. Subagents can't launch other subagents, so every handoff goes through you. Agents get context only from files in the run folder (RUN), never from paraphrase: you write what they need there and pass them paths.

`TR` below is `~/.claude/bin/tdd-run`.

## 0. Does this fit?

Use this for behavior changes with outcomes a test can observe. For trivial edits, config, or docs, say so and do the work directly.

## 1. Set up

1. `TR init <short-slug>` from inside the repo. It prints RUN.
2. Use the `Explore` agent to find: the code involved, existing tests and fixtures to reuse, the test framework, the exact test command, and what the tests need running (database, services, ports).

## 2. Brief

Fill every section of `RUN/brief.md`.
- **Acceptance criteria:** numbered and testable. If they're vague or missing, ask the user before going on. A thin brief is the main reason agents guess.
- **Test boundary:** the concrete public entry points tests may call.
- **Approach:** decide whether the task needs a design before coding (see below). If not, write `Not needed: <reason>`.

### Approach, when needed

A design is needed when any of these hold:
- a new module, package, or service
- a new data model or schema change
- a new external integration or dependency
- a change to an existing public interface, beyond adding to it
- a change that cuts across several components
- more than one plausible approach with real trade-offs

Otherwise, for example a change with one obvious shape inside existing structure, skip it.

When it's needed:

1. Run the `Plan` agent with RUN/brief.md. Ask for a concise approach: components and responsibilities, interfaces and signatures, data structures, data flow, alternatives considered and why each was rejected, and risks.
2. Write it into the brief's Approach section, with a **Build mode** (below). Keep it to what a builder needs: decisions, not essays.
3. Show the user the approach and build mode, and wait for confirmation or changes. Don't continue without it.
4. Once they confirm: `TR set RUN approach=confirmed mode=<single|sequential|parallel>`.

Then run `TR brief-check RUN` and fix anything it reports. It fails while a written approach is unconfirmed.

### Build mode

- **single** (default, and always when the approach is not needed): one builder, steps 5 and 6, no contract.
- **sequential:** several components, built one at a time in dependency order in the main tree.
- **parallel:** components in the same dependency wave are built at once, each in its own worktree.

For sequential or parallel, the approach adds a components table:

| Component | Responsibility | Owned files | Provides | Consumes | Wave |
|---|---|---|---|---|---|

- **Owned files** are paths or directories (ending in `/`) only that component may change. No overlap between components.
- **Waves** follow dependencies: a component's wave is one more than the highest wave it consumes from. Providers are built before their consumers, so every component is tested against real code, never a fake of another component (see behavior-testing.md).

Choose parallel only when all of these hold; otherwise choose sequential:
- at least one wave has two or more components
- interfaces and shared data structures can be pinned down completely in the contract
- owned files don't overlap
- if the tests need a database or ports, each builder can get its own (a separate database or schema, or a container per builder)

## 3. Baseline

Run the test command from the brief once.
- If the command doesn't work, fix the brief.
- If the tests need a database or services and they aren't reachable, stop and ask the user. Never swap in a mock or a different engine.
- Record already-failing tests: `TR set RUN baseline_failures="<names or none>"`. They won't be blamed on this change.

## 4. Contract (sequential and parallel only)

Write this yourself, in the main tree, from the confirmed approach:

1. **Interfaces as code:** every interface in the components table, with its signatures and shared data structures (types, schemas, DTOs, error types), in the repo's language. Bodies are stubs that raise a not-implemented error.
2. **Seam tests:** for each place one component calls another, a test that calls the upstream entry point, runs through the real downstream component (and the real database), and asserts on the final outcome. No doubles between components. These stay red until both sides exist.
3. Run them. The red gate applies (step 5): every seam test fails on an assertion or a not-implemented error, with no load errors.
4. Write `RUN/contract.md`: the interface files, the seam tests and which components each needs, and a `Contract files:` list with one repo-relative path per line.
5. `TR freeze RUN <contract files>`.
6. Write a **context pack** per component at `RUN/packs/<component>.md`:
   - its component row from the approach, and the acceptance criteria it covers
   - the interfaces it provides and consumes, as paths in the contract; consumed ones are already built and must be called for real
   - owned files, and what it must not touch
   - the seam tests it takes part in, and the command to run its own tests
   - its environment: database name or schema, ports
   - its output files: `RUN/test-plan-<component>.md` and `RUN/progress-<component>.md`

Contract and test files are frozen together. Each later `TR freeze` call passes the contract files plus every test file so far, because freeze replaces the frozen set.

## 5. Red

**single:**
- **Default:** the `builder` agent in mode `red`.
- **With `--independent-tests`:** the `test-writer` agent.

Check `RUN/test-plan.md` for red evidence. Every new test must fail on an assertion or a not-implemented error, with no load errors. If the gate isn't met after 2 tries, stop and escalate.

Then freeze: `TR freeze RUN <test files listed under "Test files:">` and `TR set RUN phase=green round=1`.

**sequential and parallel:** go wave by wave. Within a wave, run red for every component, then green (step 6), before the next wave starts.

- **sequential:** run the `builder` in mode `red` with RUN and its pack, in the main tree, one component at a time.
- **parallel:** for each component, `TR wt-add RUN <component> <owned files...>` prints its worktree. Launch every builder in the wave in a single message, each with RUN, its pack, and its worktree. Then `TR wt-collect RUN <component>` for each.
  - Exit 4 (changed files it doesn't own): drop it with `TR wt-drop` and rerun that builder with the files named. If it needs the file, the plan is wrong: fix the ownership.
  - Exit 5 (conflicts with the main tree): owned files overlap. Fix the ownership, drop, and rerun.

Check each `RUN/test-plan-<component>.md` for red evidence, append them to `RUN/test-plan.md`, then freeze the contract plus all test files so far.

## 6. Green

Run the `builder` agent in mode `green`, naming the latest `evaluation-N.md` from round 2 onward.
- **single:** in the main tree.
- **sequential:** with each component's pack, one at a time in the main tree.
- **parallel:** `TR wt-add` per component again, one builder per worktree launched in a single message, then `TR wt-collect` each, handling exits 4 and 5 as in step 5.

Then:

1. **Disputes:** if a progress file has a new `DISPUTE`, judge it against the brief yourself.
   - If valid, fix the test, re-freeze, and continue.
   - A second dispute in the run, or one that needs a product decision, goes to the user.
   - An `APPROACH DISPUTE` or `INTERFACE DISPUTE` always goes to the user, because they confirmed the approach. If they accept a change, update the approach and the contract, re-freeze, rerun red for the affected components, and set `approach=confirmed` again.
2. **Frozen files:** run `TR check-frozen RUN`. If tests or contract files changed without an accepted dispute, run `TR restore-tests RUN` and send the builder back.
3. **Progress:** run the full suite, then `TR record RUN <passing> <total>`. If it exits 3 (stalled), stop and escalate.

## 7. Integrate (sequential and parallel only)

After the last wave, run the full suite in the main tree. Every seam test must pass.

For a failing seam test, decide which side breaks the contract, using the contract and the test output. Run the `builder` in mode `green` in the main tree with that component's pack and the failing test named. If neither side can pass without changing an interface, that's an `INTERFACE DISPUTE`: take it to the user.

## 8. Refactor

Once all tests are green, in the main tree:

1. The `refactorer` agent with pass `code`. Then `TR check-frozen RUN` must pass.
2. The `refactorer` agent with pass `tests`.

A refactor that restores its snapshot isn't a failure. Continue with the restored state.

## 9. Evaluate

Run the `evaluator` agent with RUN and N = the current round. It must not receive progress files or your own commentary.

- **PASS:** finish.
- **FAIL:** if round < 3, run `TR set RUN round=<round+1>` and go back to step 6 with the evaluation (in the main tree, for the components the findings name). Otherwise, escalate.

## 10. Finish or escalate

`TR set RUN phase=done` (or `phase=escalated stop_reason="..."`). Then tell the user:
- each acceptance criterion and the test that covers it
- files changed, by component
- the evaluator's verdict
- refactors applied or restored
- the RUN path

Offer `/commit`. Never commit or push on your own.

## Stop and escalate when

- the red gate fails twice
- a second dispute arises, or any approach or interface dispute
- `TR record` reports a stall
- 3 rounds pass without a PASS
- an agent reports it is blocked
- the tests need a database or service that isn't available

When you escalate, give the user the specific question or blocker, not a status dump.
