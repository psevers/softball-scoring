# Data Model

## Team

Single tracked team identity.

## Player

Roster player with name, jersey, active state, batting side, throwing hand, and default defensive position.

## Season

Groups games and supplies the active/default season.

## Game

Durable game metadata:

- `id`
- `seasonID`
- `opponentName`
- `gameDate`
- `homeAway`
- innings-based or time-limited game format
- `status`
- `startingPitcherID`
- lifecycle timestamps

## LineupEntry

Tracked-team batting-order entry:

- `gameID`
- `playerID`
- batting order
- starting/current position
- active state

The batting order has a variable length. Game start validation requires exactly P, C, 1B, 2B, 3B, SS, LF, CF, RF once each; additional batting-only entries have no defensive position.

## GameEventRecord

Authoritative persisted scoring envelope:

- `id: UUID`
- `gameID: UUID`
- `sequenceNumber: Int`
- `timestamp: Date`
- `kindRawValue: String`
- `payload: Data`

Sequence numbers are positive and unique by invariant within a game. Semantic validation occurs on replay.
Undo deletes the authoritative latest eligible defensive pitch, completed Ball In Play result, tracked-team count pitch, completed tracked-team plate-appearance, or tracked-team SB/CS record without resequencing or rewriting survivors. Sequence gaps are valid, and the next append uses the maximum surviving sequence plus one.
An earlier defensive pitch edit replaces only the selected record's encoded pitch kind/payload after exact-timeline validation and complete candidate replay. The record ID, game ID, sequence number, timestamp, and every other record remain unchanged.
An earlier defensive pitch deletion removes only the selected record after exact-timeline validation and complete candidate replay. Every survivor retains its ID, game ID, sequence number, and timestamp; the deleted sequence remains a gap and the next append still uses the authoritative maximum surviving sequence plus one.
A correction session may retain multiple pitch edits and deletions keyed by their original record IDs. Each candidate rebuild preserves original order and envelope metadata for surviving records. Saving applies all payload replacements and deletions through one isolated SwiftData context and one save; no intermediate candidate is durable.

### PitchEvent payload

- `result`
- `pitcherID`
- `opponentBatterSlot`

Supported results in Slice 3:

- Ball
- Called Strike
- Swinging Strike
- Foul
- HBP

Slice 6 Undo accepts Ball, Called Strike, Swinging Strike, Foul, and HBP records, including ball four and strike three. Removing a terminal pitch reconstructs its entire plate-appearance consequence through replay. It also accepts a latest completed defensive Ball In Play result; removing that result preserves the separate counted pitch record and returns replay to pending-result state.
Slice 6 earlier-pitch edit accepts only non-terminal defensive Ball, Called Strike, Swinging Strike, and Foul records. Staging is non-durable; Save is available only when replacing the result and replaying every later record produces a valid authoritative snapshot.
Slice 6 earlier-pitch deletion accepts a defensive pitch component at any pitch result. Staging is non-durable; if removing that pitch invalidates a later result or play, the first rejected record is reported and Save remains unavailable.

### OffensivePitchEvent payload

- `batter` event-time player identity and batting-order slot
- `battingOrderSize`
- `result`

Slice 6 Undo accepts non-terminal tracked-team Ball, Called Strike, Swinging Strike, and Foul records. Removing one reconstructs the prior offensive count while preserving the surviving event-time batter context, batting-order size, and unchanged batting projection.

### OffensivePlateAppearanceEvent Undo

When the latest record is a completed tracked-team plate appearance, Undo removes that one authoritative record. Full replay restores its event-time batter and batting-order progression, prior count, bases, score, outs, and half-inning. Reprojecting the surviving events removes exactly that plate appearance's player-attributed PA, AB, hit classification, run, RBI, BB, HBP, or SO values.

### OffensiveBaseRunningEvent Undo

When the latest record is SB or CS, Undo removes that one authoritative record. The candidate resolves the runner's event-time identity from the accepted history that placed the player on base and confirms the source base, destination or out, result, and sequence. Full replay restores the runner to the prior base, removes an SB/CS and any steal-of-home run attribution, restores the prior half-inning after a third-out CS, and leaves the active batter, count, and plate-appearance progression unchanged.

## Derived—not persisted as competing truth

`GameState` is reconstructed from ordered events and currently contains inning/half, outs, count, score, bases, opponent batting slot, and pitch totals.

Future box scores and season statistics should likewise be projections, not independently edited counters.
