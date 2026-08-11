# Slice 4 Adversarial Review

Status: **Source review and local Xcode validation passed; GitHub CI remains required before merge.**

Scope: Ball In Play + runner movement + runs + outs.

## Review posture

Assume the scorer is distracted, taps an unexpected result, closes/reopens mid-play, has runners in awkward combinations, and records a play that ends the inning. Look for any path that can silently corrupt score/base/out state or pitch totals.

## Findings

### P1 — boolean third-out run handling loses valid timing-play information — FIXED

Initial design recorded only `counts` / `doesNotCount` when runners touched home on the third out. That cannot represent a timing play where two runners touch home but only one legally scores before the third out.

Fix: `BallInPlayEvent` now stores `thirdOutRunsCounted: Int?`, required only when a play creates the third out and at least one runner touches home. Validation constrains it to `0...homeTouches`; reducer increments the score by exactly that number.

Regression coverage: `timingPlayCanCountOnlySomeHomeTouches` plus Linux reducer harness.

### P1 — RBI could exceed legally counted runs on a third-out play — FIXED

A runner touching home is not necessarily a run. The first validator compared RBI only with home touches, allowing RBI to be credited when `thirdOutRunsCounted == 0`.

Fix: RBI validation now compares against legally counted runs. UI clamps RBI when third-out counted runs change.

Regression coverage: `rbiCannotExceedRunsThatCountOnThirdOut`.

### P1 — malformed runner payload could place two runners on one base — FIXED

Fix: every occupied runner source plus batter is required exactly once, and final 1B/2B/3B destinations must be unique.

Regression coverage: `validatorRejectsTwoRunnersEndingOnSameBase`.

### P1 — malformed payload could move a runner backward — FIXED

Fix: second-base runner cannot finish at first; third-base runner cannot finish at first/second. Holding is legal. Batter and first-base runner have the full destination set because they can advance multiple bases or be retired.

Regression coverage: `validatorRejectsRunnerMovingBackward`.

### P1 — additional pitch could be recorded while an in-play result was unresolved — FIXED

That would double-count pitches and detach the eventual play from its plate appearance.

Fix: Ball In Play increments pitch count immediately and sets `isAwaitingBallInPlayResult`. Recorder/replay/reducer reject another pitch until a valid play event completes the PA.

Regression coverage: `additionalPitchIsIgnoredWhileBallInPlayResultIsPending`.

### P1 — sacrifice could be credited with two outs — FIXED

A sacrifice fly/bunt cannot be credited when two outs already exist.

Fix: validator rejects `sacrificeFly` and `sacrificeBunt` when the play begins with two outs.

Regression coverage: `sacrificeFlyIsRejectedWithTwoOuts`.

### P1 — ordinary batter-out third out could incorrectly allow a run — FIXED

If GO/FO/LO/PO records the sole third out on the batter, a run cannot score on that play. A generic timing-play control incorrectly allowed the scorer to mark such a run as counted.

Fix: validator forces zero counted runs for a one-out ordinary batter-out that creates the third out; UI caps the third-out run control at zero in that state.

Regression coverage: `ordinaryBatterOutAsThirdOutCannotCountRun`.

### P1 — sacrifice labels could be accepted without sacrifice conditions — FIXED

Fix: Sac Fly now requires an existing runner to score; Sac Bunt requires an existing runner to advance. Both remain invalid when the play starts with two outs.

Regression coverage: `sacrificeFlyRequiresRunnerToScore` and `sacrificeFlyIsRejectedWithTwoOuts`.

### P1 — trailing runner could pass a runner ahead — FIXED

Fix: validator compares the ordered final positions of all non-retired runners and rejects a trailing runner that finishes at or beyond a runner who began ahead.

Regression coverage: `validatorRejectsTrailingRunnerPassingRunnerAhead`.

### P1 — force third out could incorrectly count a run — FIXED

Fix: validator derives the active force chain from starting base occupancy and rejects a positive counted-run quantity when a forced runner makes the third out.

Regression coverage: `forcedThirdOutCannotCountRun`.

### P1 — persistence boundary lacked hostile verification — FIXED

Fix: added coverage for wrong-game and malformed histories, next sequence assignment, successful save, rollback after save failure, pending/completed relaunch replay, Ball In Play codec round-trip, and third-out score survival through persisted replay.

### P1 — corrupt durable home/away value could silently change scoring side — FIXED

Fix: the write boundary rejects an invalid persisted home/away value as corrupt history, and the live game screen pauses scoring instead of replaying or displaying a writable scoring surface from the fallback value.

### P0 — stale UI snapshot could allocate duplicate event sequences — FIXED

Fix: the recorder validates the caller snapshot but allocates sequence numbers and replays from authoritative per-game records fetched from the `ModelContext`. Repeated calls with the same stale snapshot now save sequences 1 then 2 without corrupting replay.

Regression coverage: `repeatedRecorderCallsUseAuthoritativeStoredSequence`.

### P1 — multi-out third-out force/timing identity was ambiguous — FIXED

Fix: `BallInPlayEvent` now persists `ThirdOutClassification` with every third-out run decision. Force/batter-runner classifications require zero counted runs; timing classifications permit only explicit home touches. The confirmation sheet requires the scorer to select the classification rather than inferring order from final destinations.

Regression coverage: `batterRunnerThirdOutInDoublePlayCannotCountRun` and `tagThirdOutAfterEarlierForceCanCountTimingRun`.

### P2 — default FC/SAC runner suggestions are conservative, not official-scoring inference — ACCEPTED

The confirmation sheet intentionally treats suggestions as editable shortcuts. It does not attempt to infer every fielder's-choice or sacrifice runner path from partial information. The explicit movement payload remains correct after user confirmation.

Accepted because correctness is preserved and speculative automation would be riskier. Improve after real-game usability testing.

### P2 — no standalone steal/WP/PB/basepath event yet — ACCEPTED FOR SLICE

Slice 4 completes ball-in-play runner movement. Non-PA baserunning events remain an MVP backlog item and must be implemented before the product is declared game-complete.

## Hostile cases exercised

- Ball In Play counts exactly one pitch.
- Pending in-play result blocks another pitch.
- Empty-base single.
- Runner-on-first double with first→third.
- Bases-loaded home run.
- Duplicate final base occupancy rejected.
- Backward runner movement rejected.
- Run touching home on third out requires explicit counted-run number.
- RBI cannot exceed counted runs.
- Timing play can count a subset of apparent runs.
- Double play records exactly two outs.
- Third out advances half-inning and clears bases.
- Sacrifice fly with two outs rejected.
- All eight base-occupancy states exercised with a home run.
- Missing, unexpected and duplicate runner sources rejected.
- Runner holding and credited-hit batter retirement accepted.
- More than three inning outs rejected.
- Bases-loaded walk and HBP force exactly one run.
- Persisted pending and completed plays survive relaunch replay.
- Write failure rolls back the inserted event.
- Repeated writes from one stale UI snapshot receive distinct stored sequences.
- Batter-runner/force third out in a double play cannot count a run.
- A later tag third out can count a timing run after an earlier force is removed.

## Environment validation

A Linux-native Swift 6.2.1 harness compiled the pure event/state/validator/reducer files and executed representative single, timing-play, and third-out/RBI assertions.

Result: **PASS**.

Local Apple-framework validation used Xcode 26.6 and an iPhone 17 / iOS 26.5 simulator:

```bash
xcodegen generate
xcodebuild -project SoftballScoring.xcodeproj -scheme SoftballScoring \
  -destination 'platform=iOS Simulator,id=FB739517-7F6A-4309-A112-B50143709CA5' \
  test
```

Result: **58 tests passed (25 domain, 33 scoring-engine)**. The app also built, installed, launched, and rendered its Games empty state in the simulator.

The interactive navigation/data-entry portion of the handoff smoke checklist remains for a human Simulator pass because macOS accessibility automation was unavailable in this session.

## Merge decision

No unresolved P0/P1 code findings in the local checkpoint. **Do not merge until the interactive smoke checklist and GitHub CI are green.**
