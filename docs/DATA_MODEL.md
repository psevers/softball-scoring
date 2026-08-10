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
- `regulationInnings`
- `status`
- `startingPitcherID`
- lifecycle timestamps

## LineupEntry

Starting tracked-team lineup entry:

- `gameID`
- `playerID`
- batting order
- starting/current position
- active state

MVP start validation requires exactly P, C, 1B, 2B, 3B, SS, LF, CF, RF once each.

## GameEventRecord

Authoritative persisted scoring envelope:

- `id: UUID`
- `gameID: UUID`
- `sequenceNumber: Int`
- `timestamp: Date`
- `kindRawValue: String`
- `payload: Data`

Sequence numbers are positive and unique by invariant within a game. Semantic validation occurs on replay.

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

## Derived—not persisted as competing truth

`GameState` is reconstructed from ordered events and currently contains inning/half, outs, count, score, bases, opponent batting slot, and pitch totals.

Future box scores and season statistics should likewise be projections, not independently edited counters.
