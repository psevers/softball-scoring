# Current State

## Window

Window 1 continuation — **Vertical Slice 5 offensive scoring and player attribution are complete locally.**

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
- Game setup and lineup use ruled paper, graphite/serif page headings, and pencil-rule dividers instead of a flat tinted Form.
- Time-limited games use a keyboard-free 30–90 minute wheel in five-minute stops.

## Validation performed

On macOS with Xcode 26.6 and an iPhone 17 / iOS 26.5 simulator:

- `xcodegen generate`: **PASS**
- App build: **PASS**
- Domain tests: **36 PASS**
- Scoring-engine tests: **33 PASS**
- UI workflow tests: **3 PASS**
- App install/launch smoke test: **PASS**

The first Xcode test run exposed missing generated test-bundle Info.plists; `project.yml` now enables generated Info.plists for both test targets. The adversarial checkpoint also fixed runner-passing, force-third-out scoring, stale-snapshot duplicate sequences, invalid durable game values, and added persistence/replay boundary tests. Third-out events now persist whether the decisive out was a force/batter-runner out or a timing play.

The Slice 4 checkpoint manual evidence covered app install, launch, and the rendered Games empty state. The broader navigation/data-entry smoke checklist in `docs/LAPTOP_HANDOFF.md` remains separate from the focused field-feedback verification below.

Post-checkpoint field-feedback verification additionally covers a real 13-player roster in the iPhone 17 simulator: all batters could be added, the list scrolled through players 12–13 and the starting-pitcher control, reorder mode exposed every move action, and Start Game remained pinned and reachable at both standard and accessibility-extra-large Dynamic Type sizes.

Automated XCUITest coverage now synthesizes finger drags on an isolated 14-player roster, including the smallest installed iPhone 17e simulator. It verifies that Team reaches and opens a player in the Inactive section, and that Set Lineup can build, save, and open a complete 14-player game while keeping the final batter and Start Game reachable.

Time-limit setup coverage verifies the keyboard-free wheel at both 30 and 90 minutes and confirms Set Lineup remains reachable. Simulator visual inspection covers the ruled-paper Game Card, graphite/serif hierarchy, pencil rules, and large timer readout.

### Slice 5 validated checkpoint

- Offensive plate appearances snapshot real player identity rather than relying on mutable display data.
- Offensive pitches and plate appearances carry event-time batter and batting-order context, so replay does not depend on a later mutable lineup. A live count remains bound to that identity until the PA completes.
- Batting-order rollover supports both nine-player and extended orders.
- Quick Walk, HBP, Strikeout, and Home Run actions persist through the authoritative recorder.
- Hits, reached-base results, batted-ball outs, sacrifices, and double plays use a scorer-confirmed runner sheet.
- Timing plays retain exactly which runner sources scored for correct player run attribution.
- A pure batting projector derives PA, AB, R, H, 2B, 3B, HR, RBI, BB, HBP, SO, SB, and CS.
- Normal offensive Ball/Strike/Foul/Swing entry derives live count and completes player-attributed BB/K without opponent-pitcher stats.
- Standalone SB/CS events update identified runners, outs, score, and SB/CS projection without advancing the batter.
- Offensive UI displays the current player's name, jersey/position, complete counting-stat game line, and occupied bases using lineup slots.
- Cold-store reload restores the next batter, active count identity, bases, score, and batting projection.
- Latest full validation: 47 domain tests, 53 scoring tests, and 5 UI workflow tests pass on the iPhone 17 simulator.

`xcodegen generate`, the complete Xcode scheme, seeded simulator launch/visual smoke, `git diff --check`, and the fresh two-axis adversarial review pass locally with no unresolved P0/P1 findings. GitHub CI and collaborator review remain required before merge.

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

See `docs/reviews/SLICE4_ADVERSARIAL_REVIEW.md` and `docs/reviews/SLICE5_ADVERSARIAL_REVIEW.md`.

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

## Accepted limitations / backlog

- Standalone WP/PB/manual basepath events are still required for MVP.
- Undo/edit/pitch-count correction is Slice 6.
- Current pitcher remains fixed to starting pitcher until Slice 7.
- Opponent hitters are numbered slots.
- Runner suggestions for FC/SAC are conservative and intentionally editable rather than pretending to infer fielding context.
- No dedicated triple-play result yet.
- A time-limit expiration is informational until game-ending rules are implemented; the scorekeeper finalizes play manually.
- Slice 6 should extract the offensive scoring surface/view model from `LiveGameView` while adding history/undo, reducing its mixed UI/replay/persistence responsibilities.

## Current vertical slice

**Slice 6 — Undo + play history + correction engine.**

Next goals are event-log history, undo/edit/delete through replay, and pitch-count correction as specified in `docs/LAPTOP_HANDOFF.md`.

## Do not redo

Do not reopen native-vs-PWA, local-first, event-derived state, pitch-count MVP status, pencil scorebook direction, or adversarial-review requirement without field evidence. Field evidence has replaced the former nine-player batting-order baseline with a variable order plus nine defenders.
