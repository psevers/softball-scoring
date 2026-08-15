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

## Undo latest eligible action

- Ball, Called Strike, Swinging Strike, Foul, and HBP candidates restore prior state and pitcher totals through full replay.
- Bases-loaded ball four restores the three-ball count, completed batter slot, forced runner positions, run, and pitcher totals.
- HBP removes the awarded base and every forced movement together.
- Called and swinging strike three restore the two-strike count, completed batter slot, outs, and the prior half-inning when the strikeout made the third out.
- A latest completed Ball In Play result is offered separately from its preceding counted In Play pitch. Undo removes only the result and restores pending outcome entry.
- Single, double, home run, ordinary out, double play, and third-out result undo restore the complete pre-result state at the authoritative persistence/replay seam.
- A pending Ball In Play pitch is not offered by this ticket; malformed history, wrong-game candidates, moved latest actions, and stale exact timelines are rejected.
- Candidate replay succeeds before deletion, save failure rolls back every record, and surviving identity/sequence/timestamp values remain unchanged.
- A later pitch allocates from the authoritative maximum surviving sequence without collision.
- A fresh model context and cold-store reload reconstruct terminal-pitch state and pitcher totals identically to the immediate response.
- Tracked-team Ball, Called Strike, Swinging Strike, and Foul candidates restore the prior offensive count while preserving event-time batter identity and batting-order size; a two-strike foul remains pitcher-independent and restores two strikes.
- Tracked-team cancellation, stale identity, mismatched-batter replay, and save failure preserve the original timeline and batting projection.
- Tracked-team surviving IDs, timestamps, and sequence gaps remain stable; later offensive scoring allocates from the authoritative surviving maximum.
- A fresh model context and cold-store reload reproduce the same tracked batter and offensive count.
- Completed tracked-team walk, HBP, strikeout, hit, reached-base, home-run, sacrifice, ordinary-out, and double-play records restore the exact pre-play replay state and batting projection.
- Completed tracked-team confirmations use event-time player identity and state result, runner movements, runs, RBI, and sequence; current lineup metadata cannot rewrite them.
- Completed tracked-team cancellation, stale history, invalid replay, and save failure preserve the durable record and batting line. Fresh context and cold-store reload reproduce the restored snapshot.
- Accessibility XL UI coverage verifies a ball-four award path, a defensive third-out strikeout path, a completed Ball In Play result replacement, tracked-team count-pitch undo, a scoring tracked-team plate appearance, and a tracked-team third-out/inning transition, including exact confirmation, cancellation, successful deletion, and refreshed live scoring.

## Earlier defensive pitch edit

- History exposes edit only for non-terminal defensive Ball, Called Strike, Swinging Strike, and Foul components.
- Staging uses the pitch's event-time inning, half, opponent batting slot, pitcher, result, and count without mutating durable records.
- Each supported replacement runs full decode, validation, replay, history, and batting projection; the first invalid later record disables Save.
- Wrong-game, unsupported, stale-timeline, projection-failure, invalid-candidate, and save-failure paths preserve every original record.
- Valid Save changes only the selected encoded pitch payload/kind while retaining ID, game ID, sequence, and timestamp.
- Fresh-context and cold-store reload reproduce corrected count, pitcher totals, record identity, and History.
- Accessibility XL UI coverage verifies exact current/proposed event-time summaries, reachable 44-point actions, Cancel, valid Save, refreshed History/live state, and reopen persistence.

## Earlier defensive pitch deletion

- Every defensive pitch component exposes an explicit Delete action with exact inning, half, opponent slot, result, and sequence confirmation.
- Staging removes only the selected record from the in-memory candidate and replays/projects the complete remaining timeline without durable mutation.
- The first invalid downstream record disables Save; candidate rejection leaves every original record unchanged.
- Wrong-game, stale-timeline, projection-failure, and save-failure paths preserve every original record.
- Valid Save atomically deletes only the selected record; survivor IDs, sequence numbers, and timestamps remain unchanged with a sequence gap.
- The next scoring write uses the maximum authoritative surviving sequence plus one.
- Fresh-context and cold-store reload reproduce corrected count, pitcher totals, later game state, and History.
- Accessibility XXXL UI coverage verifies exact confirmation, Cancel, replay preview, Save, refreshed live state, and reopen persistence.

## Multiple staged corrections

- An invalidating first edit or deletion exposes the first rejected record with stable sequence, decoded event context, and the count/batter state reached by full replay.
- The problem summary navigates to the affected Play History entry and offers only supported pitch repair actions.
- Every additional edit or deletion rebuilds the complete candidate without skipping, reordering, rewriting, or cascade-deleting unrelated records.
- Staged changes remain reviewable by original record identity and sequence; Cancel leaves the durable timeline untouched.
- Save is unavailable for rejected replay or failed batting projection and becomes available only for a changed, clean candidate.
- One isolated save applies all staged payload replacements and deletions; simulated failure and stale history roll back or reject the entire batch.
- Fresh-context and cold-store reload reproduce the corrected game state, pitcher totals, batting projection, and Play History.
- Accessibility XXXL UI coverage invalidates a downstream defensive pitch, navigates to it, stages the repair, saves once, and returns to live scoring.

## Earlier tracked-team pitch correction

- Play History exposes Ball, Called Strike, Swinging Strike, and Foul components with their event-time player identity, lineup slot, and batting-order size.
- The persistence boundary accepts only a replacement result and preserves stable record ID, game ID, sequence, timestamp, player identity, slot, and order size.
- Candidate replay validates the event-time count and batter, preserves later batter transitions and deterministic batting projection, and exposes the first invalid downstream offensive pitch for staged repair.
- Wrong-game, stale-session, projection, invalid-candidate, failed-save, and cancellation paths leave the durable timeline unchanged.
- Fresh-context replay and the focused Accessibility XL UI workflow reproduce the edited count and same tracked batter after relaunch.

## Earlier tracked-team pitch deletion

- Play History exposes Delete separately from Edit for each tracked-team Ball, Called Strike, Swinging Strike, and Foul component; confirmation names event-time player, batting slot/order size, result, and sequence.
- Staging removes only the selected record from the candidate, leaves durable history untouched, and preserves every survivor's ID, game, sequence, timestamp, player identity, slot, and batting-order size.
- Full replay rebuilds the offensive count, tracked batter, and deterministic batting projection while retaining sequence gaps; deleting a pitch before an originally count-completing walk or strikeout rejects that plate appearance when its saved terminal-count contract no longer holds.
- The first rejected downstream tracked pitch disables Save and offers explicit edit or delete repair in the same multi-change session.
- Wrong-game, stale-session, projection, invalid-candidate, failed-save, and cancellation paths leave every durable record unchanged.
- Fresh-context replay and the focused Accessibility XL workflow reproduce the deleted-pitch count and same tracked batter after relaunch.

## Completed tracked-team plate-appearance correction

- Play History exposes Edit Play for accepted tracked-team plate appearances, including scoring, multi-out, and third-out plays, and opens with event-time player, lineup slot/order size, component history, current result, runner map, score, runs, RBI, third-out classification, and affected batting lines.
- Loaded-hit, extra-base-hit, home-run, error-without-RBI, sacrifice-fly, bases-loaded-walk, and bases-loaded-HBP replacements replay through the ordinary offensive validator and reproject PA/AB/R/H/2B/3B/HR/RBI/BB/HBP/SO/sacrifice attribution.
- Moving a runner from Home to a base or Out removes the run, team score, and runner attribution while replaying bases, outs, current tracked batter, and later history.
- A representative double play retains two explicit out sources. A third-out edit distinguishes force/batter-runner from timing classification: force counts zero runs, while timing requires the exact legal counted-run sources and applies them before the replayed half-inning transition.
- Third-out replay clears count, bases, and outs while preserving the correct next tracked batter and event-time PA/AB/result, run, and RBI attribution for the following offensive half.
- Wrong player identity, missing/duplicate/unexpected runners, backward movement, passing, collisions, excess outs, illegal sacrifice, invalid run sources, excess RBI, outcome mismatch, and ambiguous or contradictory third-out proposals cannot produce a saveable candidate; the UI identifies the exact problem while Save remains disabled.
- A rejected downstream tracked-team plate appearance identifies its exact sequence and supports a second scorer-confirmed replacement in the same session; Save remains disabled until the full timeline is clean, then both records persist atomically.
- Wrong-game, stale-session, projection, save, and cancellation paths preserve the durable timeline. Fresh-context and standard/Accessibility XL UI relaunch coverage verify representative hit-to-error-to-out correction, a scoring-double correction, and a third-out correction with current/proposed score and batting attribution, 44-point controls, next batter, bases, outs, half-inning, and History.

## Tracked-team SB/CS correction

- Play History exposes Edit Base Running only for accepted tracked-team SB/CS records and displays event-time runner identity, lineup slot/order size, source/destination, active batter/count, sequence, replay state, and R/RBI/SB/CS attribution.
- SB↔CS replacement and selection of a different event-time eligible runner preserve the exact record envelope and replay every later event.
- A steal of home reprojects team score plus runner R/SB with zero RBI. A third-out CS transitions the half while preserving the next tracked batter.
- Wrong runner, wrong source/destination, wrong half, stale timeline, projection failure, and save failure reject or roll back atomically. A rejected downstream SB/CS requires an explicit second staged replacement before Save.
- Focused standard-size UI coverage changes SB to CS, verifies outs, bases, active batter/count, History, and runner SB/CS attribution, then terminates and relaunches to verify the same durable result.

## Completed tracked-team logical-play deletion

- Play History exposes Delete Completed Play on the terminal result of an accepted tracked-team plate-appearance group while retaining individual pitch and Edit Play actions.
- Confirmation and the staged preview list every component pitch and the terminal result with exact sequences and concise summaries.
- Candidate replay removes exactly those record IDs, preserves unrelated interleaved SB/CS and later events, and rebuilds count, bases, score, outs, current tracked batter, and batting projection without the deleted result, runs, or RBI.
- A rejected downstream event disables Save and identifies the first repairable record; adding its explicit repair rebuilds the complete candidate without cascade deletion or resequencing survivors.
- When the first affected record belongs to another completed tracked-team play, the scorer can stage deletion of that entire downstream logical play rather than attempting an identity-changing edit; both exact component groups then save atomically.
- A downstream SB/CS whose runner no longer exists supports explicit staged deletion. Defensive logical plays made invalid by deleting a tracked-team third out support the same exact-component confirmation and additive logical deletion.
- Wrong-game, invalid-candidate, stale-history, failed-save, and cancellation paths preserve every original component. Fresh-context and cold-store reload preserve survivor IDs, timestamps, sequences, and gaps.
- Focused UI coverage cancels once, previews a multi-pitch completed play, stages deletion of the affected downstream completed tracked play, saves atomically, and verifies live state, batting attribution, and empty authoritative History after relaunch.

## Completed defensive logical-play deletion

- Play History exposes Delete Completed Play only for an accepted paired defensive In Play pitch and Ball In Play result while retaining individual component actions.
- Confirmation names both exact record sequences and concise pitch/result summaries.
- Candidate replay removes exactly the pair and restores pre-pitch count, bases, outs, score, batter slots, and pitcher totals without resequencing survivors.
- The first rejected downstream record disables Save and can join the same staged repair; invalid candidates do not mutate durable history.
- Wrong-game, stale-history, failed-save, and cancellation paths preserve both original components.
- Fresh-context and cold-store reload preserve surviving IDs, timestamps, sequence numbers, gaps, and the replayed state.
- Focused UI coverage previews the pair, repairs a downstream pending pitch, saves once, and verifies empty authoritative History after relaunch.

## Completed defensive Ball In Play correction

- The persistence/replay boundary replaces a saved result while retaining the paired counted In Play pitch and stable result ID, sequence, and timestamp.
- Loaded-hit, extra-base-hit, home-run, reached-on-error, sacrifice-fly, and fielder's-choice scoring paths replay expected score, bases, outs, opponent batter slot, RBI, and pitcher totals.
- Existing movement validation rejects missing, duplicate, unexpected, backward, passing, colliding, excess-out, and outcome-inconsistent proposals. Every out retains an explicit runner source, non-third-out home touches must all count, and RBI cannot exceed counted runs.
- Double-play correction records two explicit outs without changing the paired counted pitch, then restores the correct opponent batter and durable replay state.
- Third-out correction distinguishes force/batter-runner from timing scoring. Force counts zero runs; timing requires an explicit legal counted-run quantity. Contradictory, missing, or excess-out proposals cannot produce a saveable preview.
- Candidate replay applies legal runs before advancing the half-inning, then verifies zero outs, zero count, empty bases, the next opponent slot, and the tracked batter for the following half.
- Moving a runner from Home back to a base or Out removes the replayed run and attribution through fresh-context and cold-store reload.
- An invalid downstream eligible scoring or non-scoring play identifies its exact record and can join the same staged correction; Save stays disabled until replay is clean, then both replacements persist atomically.
- A downstream multi-out or third-out play can join the same staged repair when its replacement validates against the replayed event-time state.
- Wrong-game, stale-session, projection, and failed-save paths preserve the original records; fresh-context and cold-store reload reproduce the corrected state.
- Accessibility XXXL UI coverage distinguishes the counted pitch from the editable result, rejects an illegal counted-run quantity, confirms RBI, previews score/bases/pitcher replay, saves, and reopens the game with the corrected scoring play. A second focused workflow reclassifies a third-out double play from force to timing, previews the next half-inning, and verifies score/count/bases again after relaunch.

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
- Latest SB/CS Undo confirms the event-time runner, source, destination/out, result, and sequence; replay restores ordinary SB, steal-of-home, and third-out CS state without changing the active batter or count.
- Wrong-runner history, stale confirmation, candidate projection failure, and save failure leave the SB/CS timeline and batting attribution unchanged; fresh contexts and a cold-store reload reproduce the restored runner and batting line.
- Batting projection covers every PA result and credits PA/AB/H/2B/3B/HR/BB/HBP/SO/R/RBI/SB/CS without storing mutable totals.
- UI workflow records quick results and a confirmed single, then reopens the game at the correct next batter.
- Focused UI recovery records SB, confirms the exact event-time runner and movement, undoes it from Play History, and reopens the live game with the runner restored to the source base.
