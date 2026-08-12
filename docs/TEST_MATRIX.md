# Test Matrix

## Continuous integration lanes

`iOS PR Fast Verification / PR Fast Verification` is the required pull-request check. From a clean
checkout it generates the Xcode project, creates and boots a fresh compatible iPhone simulator,
builds the complete scheme for testing, runs every `DomainTests` and `ScoringEngineTests` test
(including persistence and replay coverage), and runs the deterministic
`testUndoLatestPitchConfirmsCancelsAndRestoresLiveStateFromHistory` launch/recovery smoke test.

`iOS Exhaustive UI Evidence / Exhaustive UI Evidence` is the post-merge UI matrix. It runs on every
push to `main` and by manual dispatch, builds against a newly created simulator, and runs the entire
`SoftballScoringUITests` target with parallel testing disabled and no skipped tests. Use the Actions
**Run workflow** control and select the branch under test when a release, evidence capture, or
investigation needs the matrix outside the normal `main` cadence.

An implementation ticket must request and link a successful manual exhaustive run before merge when
it changes a user workflow covered by XCUITest, UI-test fixtures or launch arguments, the UI target or
scheme, simulator/runtime selection, or either CI workflow. It must also request the lane when its
ticket, release plan, evidence plan, or investigation explicitly calls for the complete matrix. Other
pull requests are gated only by PR Fast Verification; their exhaustive evidence follows on the
resulting `main` push.

Both jobs append their status and elapsed duration in seconds to the GitHub Actions job summary on
every run, including failed runs. These per-run measurements are the CI-time regression record.

## Scorebook visual foundation

- The bundled Patrick Hand resource resolves by PostScript name in the hosted app runtime.
- Games home retains its empty and populated navigation behavior after moving from a native list to ledger sections.
- The app remains a coherent light-paper surface when the device uses Dark Mode.
- Expressive text scales from semantic Dynamic Type roles; dense metadata and numerical text retain system typography.

## Slice 5.5 retained evidence matrix

- iPhone 17e and iPhone 17 each cover standard and Accessibility XL Dynamic Type in portrait, full-screen presentation.
- Every primary configuration retains Games home, New Game, a complete nine-player lineup, live offense, live defense, offensive and defensive runner confirmation, Team/roster, player editor, Seasons, season editor, final game summary, and the supported Stats empty state.
- The complete thirteen-category batting line is reachable at both text sizes on both devices; values share a consistent baseline within each visual row.
- A representative iPhone 17 system-dark run retains the coherent light-paper app and readable native editor metadata.
- Critical state labels remain readable, essential actions remain reachable by scrolling, numerical values remain aligned, and selected/destructive/invalid meaning has non-color structure or text.
- Representative captures are shown beside the approved Window 1 reference, and the complete evidence set received explicit product-owner approval on August 12, 2026.
- The final complete Xcode scheme passes on iPhone 17 / iOS 26.5: 116 tests (119 parameterized test cases), with zero failures or skips.
- Exact capture configuration and raw Xcode attachment manifests are retained under `docs/evidence/slice5-5/`.

## Pitch/count regression

- 0/1/2 ball progression.
- Fourth ball completes BB.
- 0/1/2 strike progression.
- Third called/swinging strike completes K.
- Two-strike foul stays at two live strikes and increments pitch strike count.
- HBP total-only pitch classification.
- Ball In Play increments one pitch and enters pending-result state.
- Another pitch while pending is rejected/ignored.

## Read-only Play History

- A fresh authoritative snapshot fetches exactly one game and supplies replay, batting projection, and history together.
- Defensive and tracked-team offensive entries retain event-time batter identity and batting-order context.
- SB/CS remains a separate offensive base-running entry without advancing the active plate appearance.
- A Ball In Play pitch and result appear as one completed play with both component records available.
- An unresolved Ball In Play pitch remains explicitly pending.
- Unknown kinds, malformed payloads, and semantic rejections remain visible as problem entries.
- Entries split into event-time top/bottom half-inning sections.
- Accessibility XL UI coverage opens History from a deterministic live game, reads completed and pending plays, and returns to unchanged live state.

## Undo latest defensive count pitch

- Ball, Called Strike, Swinging Strike, and Foul candidates restore prior count and pitcher totals through full replay.
- Only the latest persisted scoring action is eligible; terminal pitches, completed plays, malformed history, wrong-game candidates, moved latest actions, and stale exact timelines are rejected.
- Candidate replay succeeds before deletion, save failure rolls back every record, and surviving identity/sequence/timestamp values remain unchanged.
- A later pitch allocates from the authoritative maximum surviving sequence without collision.
- A fresh model context and cold-store reload reconstruct the same corrected snapshot as the immediate response.
- Accessibility XL UI coverage verifies 44-point Live Game and Play History Undo controls, exact confirmation context, cancellation, successful deletion, and return to restored live scoring.

## Base occupancy matrix for Ball In Play

Exercise outcome confirmation from all eight starting base states:

1. Empty
2. 1B
3. 2B
4. 3B
5. 1B + 2B
6. 1B + 3B
7. 2B + 3B
8. Loaded

Across representative:

- 1B
- 2B
- 3B
- HR
- E
- FC
- one-out batted outs
- Sac Fly / Sac Bunt
- Double Play

## Movement invariants

- Every occupied runner + batter appears exactly once.
- Missing runner rejected.
- Unexpected runner rejected.
- Duplicate source rejected.
- Second cannot finish at first.
- Third cannot finish at first/second.
- Two runners cannot finish at same base.
- Runner may hold current base.
- Batter may be out after credited hit while attempting extra base.

## Outs and inning boundary

- Play may record zero outs.
- One out adds one.
- DP adds exactly two.
- Play cannot create >3 inning outs.
- Third out clears bases/count and advances half.
- Sacrifice credit rejected when starting with two outs.

## Third-out runs

- Home touch + third out requires explicit counted-run quantity.
- Counted run quantity must be 0...home touches.
- RBI cannot exceed counted runs.
- Zero runs count on force-style third out.
- Timing play can count one of multiple apparent home touches.
- Third-out score applied before inning transition and survives replay.

## Persistence/replay

- Encode/decode Ball In Play payload round-trip.
- Relaunch while pending Ball In Play returns to outcome selection state.
- Relaunch after completed play restores score, bases, outs, batter and pitch totals.
- Malformed/duplicate sequence history is rejected and scoring pauses.

## Game setup

- Nine-player batting order with nine regulation defenders is accepted.
- 11–13-player batting orders with exactly nine defenders and batting-only entries are accepted.
- Duplicate players, missing/duplicate regulation positions, more than nine defenders, and a pitcher not assigned P are rejected.
- Full batting order and defensive assignments survive persistence.
- Innings-based and time-limited formats survive persistence.
- Time-limit setup offers 30–90 minutes in five-minute stops without opening a keyboard.
- Both time-limit endpoints and Set Lineup remain reachable by touch on a small iPhone.
- Timed status reaches expiration without silently finalizing the game.
- Deterministic previews render a populated time-limit Game Card and a fourteen-batter lineup without relying on current dates or unordered fetches.

## Roster and lineup reachability

- A finger swipe reaches and opens the inactive player after a 14-player active Team roster.
- A 14-player batting order can be built by touch, its final batter remains reachable, and Start Game saves and opens the live game.
- With accessibility-extra-large Dynamic Type encoded in the app launch, New Game scrolls to the time-limit wheel and Set Lineup action; the fourteen-batter lineup scrolls between its last batter, pitcher control, and summary before saving.

## Administrative scorebook alignment

- Deterministic preview data covers one team, fourteen active and one inactive player, active and historical seasons, and a final game with a complete fourteen-player lineup.
- Standard-size UI evidence covers Team/roster, a native player editor, Seasons, final game summary, and the intentional Stats empty ledger.
- At Accessibility XL, a lower long-roster row and its native editor remain reachable, Seasons remains usable, the final-game summary reflows without losing navigation, and the Stats empty state remains reachable.
- Native team, player, and season editor controls retain their existing text fields, pickers, toggles, validation, confirmation, and destructive behavior.

## Live scorebook visual alignment

- Deterministic fixtures replay into an offensive state with prior batting totals, a 1–1 count, and runners on second/third; a defensive state with one out, a 1–1 count, and a runner on first; and a rejected corrupt-history state that gates scoring.
- SwiftUI previews cover offense, defense, occupied bases, outs/count, the complete batting-total grid, history protection, both runner-confirmation sheets, and Accessibility XL reflow.
- At deterministic Accessibility XL, the quick-result workflow reaches Walk, Home Run, a confirmed 1B, Record, back navigation, and persisted batter progression.
- At deterministic Accessibility XL, the normal-pitch workflow reaches count entry, SB, CS, the earlier pitch section after runner scoring, strikeout completion, and the next batter.
- At standard size, the initial live viewport exposes the current batter, count, Ball, and Strike before opening runner confirmation.
- At Accessibility XL, destination and RBI controls remain in the initial runner-confirmation viewport and retain stable accessibility identifiers.
- Standard and Accessibility XL simulator inspection checks the compact at-bat hierarchy, readable identity/numerical roles, non-overlapping runner controls, and preserved native navigation/toolbars. The final post-review ticket #8 evidence was explicitly approved on August 11, 2026.

## Tracked-team offense

- Offensive event codec preserves historical player identity and explicit counted-run sources.
- Authoritative recorder resolves the current batter from persisted lineup/player records.
- Nine- and thirteen-player orders wrap using their actual length.
- Third out preserves the next tracked batter for the following offensive inning.
- Reload/replay restores the next batter and real-player base occupancy.
- Historical events replay after current lineup metadata/order changes because each event owns its batting-order context.
- A pitch sequence cannot be completed by a different player identity at the same lineup slot.
- Cold-store reload restores batter, live count, bases, score, and derived batting projection.
- Defensive pitch recording succeeds after an offensive half-inning.
- Rapid stale offensive writes are rejected before they can score the next batter.
- Normal Ball/Strike/Foul/Swing entry completes BB/K and preserves the two-strike foul rule without opponent-pitcher stats.
- BB/HBP force only required runners; a loaded award credits the runner from third and one RBI.
- HR moves and credits every occupied real-player runner.
- Offensive ball-in-play suggestions cover hits and double plays before scorer confirmation.
- Runner passing, base collisions, backward movement, excess outs, and ordinary batter-out timing runs are rejected.
- SB advances the identified runner; CS removes that runner and adds an out without advancing the batter.
- Steal of home credits one run and SB without RBI; third-out CS advances the half and clears remaining runners.
- SB/CS rejects an occupied destination, wrong runner identity, and the wrong half-inning.
- Batting projection covers every PA result and credits PA/AB/H/2B/3B/HR/BB/HBP/SO/R/RBI/SB/CS without storing mutable totals.
- UI workflow records quick results and a confirmed single, then reopens the game at the correct next batter.
