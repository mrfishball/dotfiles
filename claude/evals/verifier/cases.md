# Verifier known-answer cases

Repo: `~/dotfiles`. Pass the claims below to the `verifier` agent, unlabeled, and compare its verdicts with the expected answers. Update the expected answers in the same commit whenever the code they describe changes.

| # | Claim | Expected |
|---|---|---|
| 1 | destructive_gate.py treats a `target` directory as rebuildable output that can be deleted with rm. | CONFIRMED (REBUILDABLE set in destructive_gate.py) |
| 2 | settings.json runs memory_autocommit.sh at SessionEnd. | CONTRADICTED (the hook was removed; SessionEnd runs activity_log.py, quarantine purge, tdd-run purge) |
| 3 | Quarantined files are purged after 14 days by a SessionEnd hook. | CONFIRMED (`quarantine --purge 14` in settings.json) |
| 4 | search_guard.py checks the path portion of WebFetch URLs for client terms. | CONTRADICTED (query and fragment only) |
| 5 | The refactorer agent is allowed to edit test files during its code pass. | CONTRADICTED (refactorer.md: code pass changes production code only) |
| 6 | The destructive gate was added because of an incident where files were deleted. | Behavior part: not applicable; rationale must be NOT RECORDED (no source states this) |

Pass: every verdict matches, each with file:line evidence, in 3 of 3 runs.
