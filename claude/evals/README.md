# Agent evals

Hooks have deterministic tests (`hooks/test.sh`). Agents need known-answer evals: fixed cases with a known correct result, run several times because model output varies.

- **pass@k**: at least one of k runs passes. Shows the agent *can* do it.
- **pass^k**: all k runs pass. Shows it *reliably* does it.

Use pass^3 for anything the workflow relies on unattended. Run the relevant eval after changing an agent's prompt, the testing standard, or the `/tdd` skill, and before committing that change. Record results in the commit message (for example `evals: refactor-survival 3/3, newcomer 3/3`).

Run evals from a Claude Code session: ask Claude to run the named eval from this file. Work happens in fresh temp folders, never in a real repo.

## 1. Refactor survival (test-writer, builder red mode)

Do the tests check behavior rather than implementation?

1. Make a temp folder containing `refactor-survival/spec.md` and `impl_original.py` copied as `pricing.py`. `git init` it and commit.
2. Run the `test-writer` agent with this prompt: write behavior tests for `pricing.price_order` per `spec.md`, test boundary `pricing.price_order`, tests in `tests/test_pricing.py` using `unittest`. It may read the signature of `price_order` only.
3. Grade: `refactor-survival/grade.sh <temp folder>`.

Pass: the tests pass on `original` and `refactored`, and fail on every `buggy_*` version.
- Failing on `refactored` means the tests are coupled to the implementation.
- Passing on a buggy version means they miss a behavior, usually a boundary.

## 2. Newcomer readability (tests as a manual)

Can someone learn the behavior from the tests alone?

1. Take the tests from a passing eval 1 run.
2. Run a fresh general-purpose agent given **only** `tests/test_pricing.py` (no spec, no source). Ask it to list every behavior of `price_order` the tests describe, with exact values and error messages.
3. Compare its list with criteria C1 to C8 in `spec.md`.

Pass: all 8 criteria recovered, with no invented behavior.

## 3. Verifier

See `verifier/cases.md`. Pass: every verdict matches with file:line evidence.

## 4. Refactorer

Does it keep behavior, keep tests frozen in the code pass, and leave things no worse?

1. Make a temp repo from a passing eval 1 run, and commit it.
2. Create a run: `tdd-run init eval`, write a minimal brief (criteria C1 to C8, boundary `pricing.price_order`, command `python3 -m unittest discover -s tests`), and `tdd-run freeze <run> tests/test_pricing.py`.
3. Run the `refactorer` agent with pass `code`, then pass `tests`.

Pass:
- all tests green after each pass
- `tdd-run check-frozen` clean after the code pass
- after the tests pass: the same number of tests, and `refactor-survival/grade.sh` still passes
- no change to the public signature of `price_order`

## 5. Evaluator (seeded defects)

Does it catch what it should?

1. Take a passing eval 1 workspace. Seed one defect per run:
   - delete the boundary test for C3
   - add `from pricing import SHIPPING` and assert on it
   - wrap a behavior in a bare `except: pass`
   - in the C2 coupon test, replace the real `SAVE10` coupon with `mock.patch.dict("pricing.COUPONS", {"FAKE": Decimal("0.10")})` and use `FAKE` (a fake of code in this codebase)
2. Run the `evaluator` agent on a run folder for that workspace.

Pass: FAIL verdict with a blocking finding that names the seeded defect at the right file:line.

The pricing workspace has no database, so the "mocked database" checklist item isn't seeded here. Seed it in a real project's run when one is available.
