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
Undo deletes the authoritative latest eligible defensive pitch or completed Ball In Play result record without resequencing or rewriting survivors. Sequence gaps are valid, and the next append uses the maximum surviving sequence plus one.

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

## Derived—not persisted as competing truth

`GameState` is reconstructed from ordered events and currently contains inning/half, outs, count, score, bases, opponent batting slot, and pitch totals.

Future box scores and season statistics should likewise be projections, not independently edited counters.
