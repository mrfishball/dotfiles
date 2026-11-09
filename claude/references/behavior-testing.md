# Behavior testing standard

Tests describe what the system does, not how it does it. If the implementation changes but the behavior doesn't, every test keeps passing. Someone new to the codebase should be able to read the tests like a manual and learn the expected behavior.

Read this before writing, tidying, or reviewing tests. It applies in any language: use the repo's own framework and conventions.

## 1. Test behavior through the public boundary

- Call only the entry points named in the brief's **Test boundary** (a public function, class, endpoint, CLI, or message handler). Never import private helpers or internal classes.
- Assert on observable outcomes: return values, errors raised, state readable back through the public API, persisted records, emitted messages or responses.
- Never assert on internal call order, private fields, or intermediate variables.
- Assert only what the requirement cares about. Check the fields that matter; don't snapshot whole objects.
- Prefer the highest level that is still fast and deterministic: behavior tests at the module or service boundary with in-memory dependencies survive refactoring best. Keep fine-grained unit tests for pure logic with many cases.

## 2. Mock only at the edges

- Replace what you don't own, or what is slow or nondeterministic: network, external services, clock, randomness, sometimes the filesystem.
- Prefer in-memory fakes over mocks.
- Never mock collaborators inside the code under test.
- Assert on a mock call only when that call is the behavior (for example, "sends exactly one notification").

## 3. Derive cases from the spec

- At least one test per acceptance criterion.
- Add the edge cases the spec implies: empty, boundary values on both sides of a threshold, invalid input, error paths.
- Don't invent requirements. If behavior is unspecified, raise it as a question instead of testing a guess.

## 4. Make tests read like a manual

- **Names state the behavior as a sentence:** `rejects_orders_past_their_expiry_date`, not `test_validate_calls_parser`. The list of test names alone should describe the system.
- **Group by feature or behavior.** Order each group: happy path, then edge cases, then errors.
- **One behavior per test**, with visible given / when / then and a single action.
- **Meaningful values:** `yesterday`, `a_premium_customer()`, not `1699999999` or `"abc"`.
- **No logic in tests:** no loops or conditionals that compute expected values. Use parameterized cases with readable case names.
- **Comments only for why**, such as the business rule a case comes from.

## 5. Shared setup: fixtures and builders

- **Extract when the same setup appears 3 or more times.** Below that, keep it inline; extracting earlier is speculative.
- **Reuse first:** search for existing fixtures, builders, factories, and helpers, and extend them instead of creating parallel ones.
- **Extract the incidental, keep the essential:** fixtures and test-data builders hold setup the test doesn't care about, with sensible defaults. The test body states only the values that drive the behavior under test:

  ```
  order = an_order(status=EXPIRED)      # the one fact this test is about
  result = place_order(order)
  expect result is rejected with "order expired"
  ```

- **No mystery guests:** an assertion must never depend on a value hidden inside a fixture. If it matters to the outcome, it appears in the test.
- **Repeated checks get names:** an assertion pattern used 3 or more times becomes a domain-named helper such as `assert_rejected(result, reason)`.
- Put shared setup where the repo's framework expects it (shared fixture files, setup methods, factories).

## 6. Deterministic and isolated

- Control time and randomness. Never `sleep` to wait for something.
- No shared mutable state between tests; any order, any subset must pass.
- No dependence on network or machine-specific paths unless the test is explicitly an integration test and marked as one.

## Review checklist

Reviewers flag, with file:line:

- calls past the test boundary, private imports, or assertions on internals
- mocks of internal collaborators, or call-count assertions that aren't the behavior
- whole-object snapshots where specific fields would do
- setup repeated 3+ times and not extracted, or existing fixtures ignored
- mystery guests (assertions relying on values hidden in fixtures)
- logic in tests
- names that don't state a behavior
- nondeterminism (time, randomness, ordering, sleeps)
- acceptance criteria with no test that would fail if the behavior broke
