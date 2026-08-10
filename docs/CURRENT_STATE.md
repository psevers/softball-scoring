# Current State

## Window

Window 1 continuation — **Vertical Slice 4 implementation complete, adversarially reviewed, and validated on macOS/Xcode.**

## Canonical repo

https://github.com/psevers/softball-scoring

## Working product surface

### Foundation through Slice 3

- SwiftUI app shell: Games / Stats / Team.
- SwiftData local persistence.
- Team, roster and season management.
- Game creation with innings-based or time-limited formats.
- Variable batting orders with exactly nine independent regulation defensive assignments and a starting pitcher.
- Resume in-progress game.
- Pencil/graph-paper scorebook visual language.
- Persisted event stream + deterministic replay.
- Defensive pitch-by-pitch count/pitch totals, BB, K, HBP, forced walk/HBP movement.
- Mandatory adversarial review policy + PR template.

### Slice 4 — Ball In Play

- Added `PitchResult.ballInPlay`; the pitch is counted immediately as a pitch strike.
- Ball In Play enters `isAwaitingBallInPlayResult`; another pitch cannot be recorded until the play is completed.
- Added result types: 1B, 2B, 3B, HR, E, FC, GO, FO, LO, PO, Sac Bunt, Sac Fly, DP.
- Added explicit `BallInPlayEvent` + `RunnerMovementEvent` payloads.
- Batter and every occupied runner receive one explicit final destination.
- `BallInPlayValidator` rejects missing/duplicate runners, backward movement, base collisions, excess outs, invalid outcome shapes, illegal two-out sacrifices, impossible RBI, and ambiguous third-out runs.
- Runner confirmation sheet suggests ordinary destinations but keeps the scorer in control.
- Runs/outs/bases update from replay, not direct UI mutation.
- Third-out timing plays support `thirdOutRunsCounted` from 0...N, including partial-count scenarios.
- RBI placeholder is captured and cannot exceed legally counted runs.
- Third out advances half-inning and clears bases/count.
- Live defense uses the approved pencil-scorebook surface for pitch → outcome → runner-confirm flow.

## Validation performed

On macOS with Xcode 26.6 and an iPhone 17 / iOS 26.5 simulator:

- `xcodegen generate`: **PASS**
- App build: **PASS**
- Domain tests: **33 PASS**
- Scoring-engine tests: **33 PASS**
- App install/launch smoke test: **PASS**

The first Xcode test run exposed missing generated test-bundle Info.plists; `project.yml` now enables generated Info.plists for both test targets. The adversarial checkpoint also fixed runner-passing, force-third-out scoring, stale-snapshot duplicate sequences, invalid durable game values, and added persistence/replay boundary tests. Third-out events now persist whether the decisive out was a force/batter-runner out or a timing play.

The Slice 4 checkpoint manual evidence covered app install, launch, and the rendered Games empty state. The broader navigation/data-entry smoke checklist in `docs/LAPTOP_HANDOFF.md` remains separate from the focused field-feedback verification below.

Post-checkpoint field-feedback verification additionally covers a real 13-player roster in the iPhone 17 simulator: all batters could be added, the list scrolled through players 12–13 and the starting-pitcher control, reorder mode exposed every move action, and Start Game remained pinned and reachable at both standard and accessibility-extra-large Dynamic Type sizes.

Earlier source-only validation:

Swift 6.2.1 Linux pure-domain harness compiled event/state/validator/reducer code and executed representative:

- Ball In Play pitch counting.
- Empty-base single.
- Pending-play pitch lock.
- Timing play where one run counts before third out.
- RBI rejection when a home touch does not legally score.

Result: **PASS**.

`Tests/ScoringEngineTests/GameStateTests.swift` also contains broader Xcode test coverage for walks/fouls/HBP, singles/doubles/HR, base collisions, backward movement, third-out runs, DP, sacrifice legality, inning transitions, and defensive-half guards.

## Adversarial review

See `docs/reviews/SLICE4_ADVERSARIAL_REVIEW.md`.

No unresolved P0/P1 findings. Important fixes discovered during review include:

1. boolean third-out run handling replaced with integer counted-run quantity;
2. RBI constrained to legally counted runs, not mere home touches;
3. base collisions/backward movement rejected;
4. pending in-play result blocks additional pitches;
5. sacrifices rejected when play begins with two outs.
6. runner passing and force-third-out scoring rejected;
7. corrupt durable game side blocks replay and new writes;
8. persistence save/rollback and relaunch replay verified.
9. repeated writes allocate from authoritative stored history;
10. multi-out plays explicitly classify the third out as force/batter-runner or timing.

## Required before merge

Push the validated checkpoint, open a draft PR, and merge only after GitHub CI is green and the PR adversarial checklist is complete.

## Suggested checkpoint commit

Validated checkpoint:

```bash
git add .
git commit -m "feat: add ball-in-play runner scoring"
git push
```

Do not merge until GitHub CI is green.

## Accepted limitations / backlog

- Tracked-team offense is still a placeholder; Slice 5 owns player-attributed offensive PAs.
- Standalone SB/CS/WP/PB/manual basepath events are still required for MVP.
- Undo/edit/pitch-count correction is Slice 6.
- Current pitcher remains fixed to starting pitcher until Slice 7.
- Opponent hitters are numbered slots.
- Runner suggestions for FC/SAC are conservative and intentionally editable rather than pretending to infer fielding context.
- No dedicated triple-play result yet.
- A time-limit expiration is informational until game-ending rules are implemented; the scorekeeper finalizes play manually.

## Next vertical slice

**Slice 5 — Full tracked-team offensive scoring + player attribution.**

Goals:

- Reuse the same PA/result/movement concepts when our team bats.
- Derive current tracked-team batter from the full persisted lineup order.
- Attribute PA outcome, runs and RBI to real `Player` IDs.
- Preserve event/replay determinism.
- Begin batting-stat projection inputs (PA/AB/H/2B/3B/HR/BB/HBP/SO/R/RBI) without storing mutable totals.
- Keep pitch tracking optional/quick on offensive half; do not require opponent-pitcher tracking for MVP.
- Add hostile batting-order rollover and stat-rule tests.
- Exercise rollover using the actual lineup length, including both 9-player and 13-player orders.

## Do not redo

Do not reopen native-vs-PWA, local-first, event-derived state, pitch-count MVP status, pencil scorebook direction, or adversarial-review requirement without field evidence. Field evidence has replaced the former nine-player batting-order baseline with a variable order plus nine defenders.
