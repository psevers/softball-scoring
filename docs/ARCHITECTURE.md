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
GameEventBody.offensivePitch(OffensivePitchEvent)
GameEventBody.offensivePlateAppearance(OffensivePlateAppearanceEvent)
GameEventBody.offensiveBaseRunning(OffensiveBaseRunningEvent)
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

Tracked-team offense uses self-contained events. A plate appearance snapshots the historical
player ID, lineup slot, lineup size, display name, jersey number, and starting position, then records
explicit runner movements and the exact runner sources whose touches of home count. Non-terminal
Ball/Strike/Foul/Swing inputs use `OffensivePitchEvent`; ball four and strike three become the same
authoritative plate-appearance events as quick results. SB/CS use a player-ID base-running event and
do not advance the batter. Historical replay requires no current mutable lineup context. Derived
`OffensiveCountContext` binds a live count to the same event-time batter identity and lineup size
until the plate appearance completes.

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
        ↓ accepted/rejected event trace with before/after state
GameReducer.apply
        ↓
GameState
        ↓ one authoritative game snapshot
SwiftUI / batting projection / Play History
```

Malformed history is surfaced rather than silently skipped; new writes are blocked while rejected records exist.
Unknown kinds, malformed payloads, invalid sequence numbers, and semantic rejections retain
their event-time replay position in the trace so Play History can show explicit problem entries.

`LiveGameSnapshotLoader` performs one fresh fetch scoped to a single game and produces the
ordered records, replay result, accepted-event batting projection, and read-only Play History.
`LiveGameSession` owns that snapshot for the live scoring and history screens; successful writes
refresh it through the same loader rather than rebuilding projections independently in each view.

## Derived game state

Derived state includes:

- inning / half
- outs
- balls / strikes
- home / away score
- opponent batter slot 1...9
- first / second / third runner slot
- tracked-team batter slot using the actual persisted lineup length
- first / second / third tracked runner player ID
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

## Feature evolution

- Slice 5: tracked-team offensive PAs, pitch entry, SB/CS, and player attribution/stat projection inputs.
- Slice 6: read-only Play History is delivered; undo/edit/count correction remains on the same event-history boundary.
- Slice 7: pitcher-change events and current-pitcher replay state.
- MVP follow-up: non-PA runner events beyond SB/CS (WP/PB/manual advance/out).
- Slice 8+: box-score and season-stat projectors consume the same event stream.
