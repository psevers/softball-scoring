# Adversarial Code Review Policy

No pull request is mergeable until it receives an adversarial review.

The reviewer's job is to find a way the change fails in a live softball game, corrupts persisted history, produces incorrect statistics, or leaves the scorer unable to recover. A review that only restates the implementation is not sufficient.

## Required review sequence

1. Read the product invariant and acceptance criteria for the slice.
2. Identify the state that must never become invalid.
3. Construct hostile scenarios around boundaries, interruption, replay, persistence, and repeated input.
4. Run or add tests that reproduce those scenarios.
5. Record findings on the PR, including zero-findings explicitly.
6. Re-run the adversarial cases after fixes.
7. Approve only when CI is green and no P0/P1 findings remain.

## Severity

- **P0** — data loss/corruption, wrong score with no reliable recovery, crash/blocker in core scoring.
- **P1** — incorrect stats/state, broken undo/replay, common game-day flow materially blocked.
- **P2** — confusing UX or correctness issue with an obvious workaround.
- **P3** — polish/maintainability issue with no immediate game-day impact.

P0 and P1 findings block merge. P2/P3 may be accepted only with an explicit rationale and backlog ticket.

## Scoring-engine standard

Any PR that changes the event model, reducer, runner movement, outs, runs, pitch count, pitcher attribution, or stat projection requires scenario tests demonstrating both the intended case and at least one adversarial neighboring case.

The reducer must remain deterministic: the same ordered event history must always produce the same game state.

## Merge ownership

The author cannot satisfy the adversarial gate by self-approval. If only one coding agent/person is available, run a distinct adversarial-review pass with fresh context/instructions and record the results before merge. Human repository settings should require a review when collaborator workflow permits it.
