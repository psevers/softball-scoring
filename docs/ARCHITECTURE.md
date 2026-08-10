# Architecture

## Stack

- Swift 6
- SwiftUI
- SwiftData
- iOS 18+
- XcodeGen project definition
- Local-only persistence

## Feature organization

```text
App/
Domain/
Persistence/
ScoringEngine/
Features/
  Games/
  Stats/
  Team/
DesignSystem/
Tests/
docs/
```

The reducer/domain layer does not depend on SwiftUI. Live scoring renders derived state rather than owning mutable scoring truth.

## Durable setup entities

- `Team`
- `Player`
- `Season`
- `Game`
- `LineupEntry`
- `GameEventRecord`

`Game` supports innings-based and time-limited formats without changing the shipped Slice 4 SwiftData schema. Domain accessors isolate the backward-compatible durable representation from setup and scoring views.

IDs are used across durable records rather than a broad SwiftData relationship graph. Event payloads remain explicit and export/migration-friendly.

## Event architecture

`GameEventRecord` is the persisted envelope:

```text
id
gameID
sequenceNumber
timestamp
kindRawValue
payload: Data
```

Typed bodies now include:

```text
GameEventBody.pitch(PitchEvent)
GameEventBody.ballInPlay(BallInPlayEvent)
```

A Ball In Play PA is deliberately two-stage:

```text
PitchEvent(.ballInPlay)    // counts the pitch immediately
        ↓
GameState.isAwaitingBallInPlayResult = true
        ↓
BallInPlayEvent            // explicit runner destinations + result
        ↓
PA completes / count resets / batter advances
```

This prevents a ball in play from either missing a pitch or counting it twice.

## Explicit runner movement

`BallInPlayEvent` records one `RunnerMovementEvent` for the batter and every occupied base at play start. Each movement uses a source (`batter`, `first`, `second`, `third`) and destination (`first`, `second`, `third`, `home`, `out`).

`BallInPlayValidator` rejects:

- missing/duplicate/unexpected runner sources,
- backward base movement,
- two runners finishing on one base,
- more than three inning outs,
- outcome/destination mismatches,
- illegal sacrifice credit with two outs,
- impossible RBI counts,
- ambiguous third-out run scoring.

When a play creates the third out and runners touch home, `thirdOutRunsCounted` explicitly records how many of those touches legally score. This supports timing plays where only a subset counts.

## Replay path

```text
SwiftData GameEventRecord[]
        ↓ ordered + validated
GameEventReplay
        ↓ typed DecodedGameEvent
GameReducer.apply
        ↓
GameState
        ↓
SwiftUI / later stat projectors
```

Malformed history is surfaced rather than silently skipped; new writes are blocked while rejected records exist.

## Game state through Slice 4

Derived state includes:

- inning / half
- outs
- balls / strikes
- home / away score
- opponent batter slot 1...9
- first / second / third runner slot
- pending ball-in-play state
- pitch totals/ball/strike counts by pitcher

## Write path

`GameEventRecorder` is the main-actor persistence boundary:

1. Validate supplied records belong to the game.
2. Replay and reject corrupt history.
3. Verify the current half/state accepts the requested event.
4. Construct next sequence number.
5. Insert one event.
6. Save SwiftData.
7. Roll back and surface save failure.

No accumulated score/stat record is directly mutated by a scoring tap.

## Future evolution

- Slice 5: tracked-team offensive PAs + player attribution/stat projection inputs.
- Slice 6: undo/edit/count correction through event history + replay.
- Slice 7: pitcher-change events and current-pitcher replay state.
- MVP follow-up: non-PA runner events (SB/CS/WP/PB/advance/out).
- Slice 8+: box-score and season-stat projectors consume the same event stream.
