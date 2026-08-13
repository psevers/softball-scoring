# Current State

## Window

Window 1 continuation — **Slice 5.5 scorebook visual alignment remains complete and approved. Slice 6 read-only Play History and latest eligible-action Undo are implemented through ticket #31; publication remains separate.**

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
- Game setup and lineup use contiguous ruled ledger rows, graphite/handwritten page headings, and pencil-rule dividers instead of a generic Form or stacked cards.
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

Time-limit setup coverage verifies the keyboard-free wheel at both 30 and 90 minutes and confirms Set Lineup remains reachable. Simulator visual inspection covers the ruled-paper Game Card, graphite/handwritten hierarchy, pencil rules, and large timer readout.

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
- Latest full validation: 48 domain tests, 53 scoring tests, and 5 UI workflow tests pass on the iPhone 17 simulator.

`xcodegen generate`, the complete Xcode scheme, seeded simulator launch/visual smoke, `git diff --check`, and the fresh two-axis adversarial review pass locally with no unresolved P0/P1 findings. GitHub CI and collaborator review remain required before merge.

### Slice 5.5 foundation — ticket #6

- Patrick Hand Regular is bundled with its SIL Open Font License and registered through the generated app configuration.
- Semantic typography separates expressive page/team/player/notation roles from system body copy and monospaced numerical roles.
- Reusable ledger sections, rows, labels, stat grids, key buttons, and empty-ledger treatments are available for the remaining Slice 5.5 surfaces.
- Games home is the first end-to-end ledger surface, with deterministic empty and populated previews.
- The root app forces a coherent light-paper appearance even when the device uses Dark Mode.

### Slice 5.5 Game Card and lineup — ticket #7

- New Game and Set Lineup now share a contiguous ruled scorebook-page treatment while retaining native fields, wheel picker, menus, reorder/delete controls, and pinned Start Game action.
- Expressive headings, player names, and short actions use Patrick Hand; editable copy and instructions stay in semantic system text; batting order, jersey, position, timer, and lineup totals use tabular system numerals.
- Deterministic previews cover a populated time-limit Game Card and a complete fourteen-batter lineup.
- Focused UI verification launches deterministically at accessibility-extra-large Dynamic Type and passes for the 30/90-minute wheel, Set Lineup reachability, all fourteen batters, starting pitcher, lineup summary, save, and reopen workflow.
- Standard and accessibility-size iPhone 17 screenshots were captured for product review; explicit product-owner approval and the full Slice 5.5 small-device evidence set remain pending.

### Slice 5.5 live scoring and runner confirmation — ticket #8

- Live offense and defense begin with one compact at-bat cell containing inning/half, score, active player, count, outs, and base state. Pitch and scoring actions immediately follow it in the first working viewport.
- Standard layouts use concise Patrick Hand identity/notation with system monospaced numbers. Accessibility sizes replace decorative marks with a compact textual summary and system headline/body roles.
- Pitch, quick-result, ball-in-play, and base-running actions use two-column scorebook keys when content permits without reducing the 52pt live-action target. Positive actions use muted green; caught stealing and validation/history failures use explicit destructive red labels as well as words/icons.
- The diamond and out marks use layered graphite strokes for pencil character. Occupied bases use muted green plus the runner's lineup slot and a complete accessibility label, so color and geometry are never the only signal.
- Both runner-confirmation sheets begin with the recorded outcome and "Confirm each runner's destination," followed immediately by destination and RBI controls. Longer attribution guidance is available in a disclosure after those controls.
- The complete thirteen-category batting line remains aligned after the scoring controls rather than delaying the primary actions.
- Deterministic previews cover offense with prior batting totals and runners on second/third, defense with a runner and out, scoring locked by corrupt history, standard and Accessibility XL live layouts, and both runner-confirmation variants.
- The fixture test executes each preview history and verifies its intended replay state. Both public offensive UI workflows launch at deterministic Accessibility XL and pass through quick results, runner confirmation, normal count entry, SB/CS, and persisted progression.
- Standard and Accessibility XL iPhone 17 screenshots of the compact live cell and runner sheet were captured, visually inspected, and explicitly approved by the product owner on August 11, 2026, including the restored game status and Accessibility XL outcome columns. The broader Slice 5.5 small-device evidence set remains pending.

### Slice 5.5 administrative surfaces — ticket #9

- Team/roster, season selection and editors, final game summary, and Stats now share the ruled-paper, graphite, expressive-name, tabular-number, and restrained-rule system.
- Native Forms, fields, pickers, toggles, swipe actions, confirmation dialogs, validation, and existing accessibility identifiers remain intact.
- Game summary renders only persisted status, season, format, starting pitcher, and lineup facts. Stats retains an intentional empty ledger rather than introducing a new projection or storage model.
- Deterministic previews cover the long active/inactive roster, active and historical seasons, a final fourteen-player game summary, Stats, and Accessibility XL reflow.
- Focused simulator verification covers all four administrative surfaces and a native player editor at standard size, plus long-roster, player-editor, season, summary, and Stats reachability at Accessibility XL.
- The complete Xcode scheme passes on iPhone 17 / iOS 26.5: 112 tests (115 parameterized test cases), with zero failures or skips.

### Slice 5.5 evidence and approval — ticket #10

- Repository evidence now retains Games home, New Game, a complete lineup, live offense, live defense, both runner-confirmation variants, Team/roster, player editor, Seasons and editor, final game summary, Stats empty state, and the complete batting line.
- The primary matrix covers iPhone 17e and iPhone 17 at standard and Accessibility XL Dynamic Type. A representative iPhone 17 system-dark run proves that the intentionally light paper presentation remains coherent.
- Exact Xcode, runtime, simulator, appearance, content-size, fixture, orientation, test, and result-bundle metadata is recorded in `docs/evidence/slice5-5/manifest.json`.
- The evidence pass exposed misaligned Accessibility XL batting-stat values. The adaptive grid now scales its minimum column width with Dynamic Type, and XCUITest verifies reachability and value alignment for all thirteen stat categories.
- The approved Window 1 reference is presented beside representative implementation captures in `docs/evidence/slice5-5/README.md`.
- Patrick Severs explicitly approved the complete evidence set on August 12, 2026: "approved. this is good".
- Final correctness/security and maintainability/scope re-reviews against `cda3da4` report no remaining P0, P1, or P2 findings.
- Final local validation on iPhone 17 / iOS 26.5 passes the complete scheme: 116 tests (119 parameterized test cases), with zero failures or skips.

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

## Required before publication

Keep ticket #10 local until explicitly authorized to push. Before merge, publish the validated branch, open a draft PR, require green GitHub CI, and complete the PR adversarial checklist. Product-owner visual approval is already recorded.

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

**Slice 6 — Undo the latest tracked-team SB or CS, ticket #32.**

The live game and Play History now share one fresh game-scoped snapshot containing replay,
accepted-event batting projection, and a history trace. History groups event-time half-innings and
plate appearances, pairs completed Ball In Play records, keeps pending plays visible, preserves
component pitches, and exposes unreadable or rejected records as problem entries. Live Game and Play
History now offer confirmed Undo when the latest action is an eligible defensive Ball, Called Strike,
Swinging Strike, Foul, HBP, completed Ball In Play result, tracked-team Ball, Called Strike,
Swinging Strike, Foul, or a completed tracked-team plate appearance. Ball four, strike three, and HBP
confirmations identify the completed plate
appearance; authoritative replay restores count, batter slot, runners, score, outs, half-inning, batting
projection, and pitcher totals without reverse mutation. The correction boundary freshly verifies the exact
game timeline, previews the surviving replay/projection, atomically deletes with rollback, and refreshes the
shared snapshot. A completed Ball In Play confirmation distinguishes its result from the preceding counted
pitch; removing only the result restores pending outcome entry so a replacement can be recorded immediately.
Tracked-team pitch confirmation names the event-time player, batting-order slot and size, result, and
sequence. Replay restores the prior offensive count without touching pitcher totals or the player-attributed
batting projection, and relaunch reproduces the same active batter context.
Completed tracked-team plate-appearance confirmation uses the event-time player identity and names the
result, runner movements, runs, RBI, and sequence. Removing the record through the same correction boundary
restores count, bases, score, outs, half-inning, and batting-order progression while reprojecting every
player-attributed batting value from the surviving timeline.
Latest SB/CS confirmation resolves and names the event-time runner, source base, destination or out, result,
and sequence. Removing the record through authoritative replay restores the runner to the source base,
removes only that runner's SB/CS attribution and any steal-of-home run, returns to the prior offensive half
after a third-out CS, and preserves the active tracked batter, count, and plate-appearance progression.
Earlier-event edit/delete and pitch-count correction remain later Slice 6 work.

## Do not redo

Do not reopen native-vs-PWA, local-first, event-derived state, pitch-count MVP status, pencil scorebook direction, or adversarial-review requirement without field evidence. Field evidence has replaced the former nine-player batting-order baseline with a variable order plus nine defenders.
