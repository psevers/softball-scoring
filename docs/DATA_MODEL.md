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
A completed defensive logical-play deletion removes its paired In Play pitch and Ball In Play result record IDs together. The staged candidate starts from the state before the pitch, and the saved timeline preserves every surviving envelope and both deleted sequence gaps without resequencing.
A correction session may retain defensive or tracked-team pitch edits and deletions, eligible Ball In Play replacements, paired logical-play deletions, and pitch-reconciliation association repairs keyed by their original record IDs. Each candidate rebuild preserves original order and envelope metadata for surviving records. Saving applies all payload replacements and deletions through one isolated SwiftData context and one save; no intermediate candidate is durable.

A `PitchCountReconciliationEvent` may persist a `RelatedDefensivePlayReference` containing the target record ID, game ID, sequence number, event kind, and SHA-256 digest of its canonical JSON payload revision. The reference is optional for backward compatibility, but when present replay requires an exact match to an earlier accepted completed defensive play. Editing or deleting that target therefore invalidates the reconciliation explicitly; a correction session must stage a new exact reference or an explicit association removal before saving atomically. If the related-play deletion also leaves a signed adjustment invalid against the candidate pitcher totals, the same staged-change channel explicitly deletes the reconciliation record rather than silently detaching or skipping it.

A completed defensive Ball In Play correction replaces only the result record payload. Its paired In Play pitch remains unchanged and counted. The replacement keeps the result ID, game ID, sequence number, and timestamp; full replay derives the corrected score, bases, outs, opponent batter slot, tracked batter slot, pitcher totals, and later history before Save becomes available. Existing movement destinations and RBI fields encode ordinary scoring corrections. A third-out correction also uses the existing `thirdOutClassification` and `thirdOutRunsCounted` fields so force/batter-runner outs count zero runs while timing plays count only legal pre-out home touches; no durable schema change is required.

A completed tracked-team plate-appearance correction replaces only its event payload while preserving the record envelope. Existing runner destinations, `countedRunSources`, RBI, and `thirdOutClassification` fields encode the corrected score, explicit out/run sources, and exact event-time player attribution. Force/batter-runner third outs carry no counted run sources; timing plays carry only the legal sources that touched home before the out. Replay and batting projection derive the inning transition, next tracked batter, every affected runner run, and batter RBI; no durable schema change is required.

A tracked-team base-running correction replaces only the existing `OffensiveBaseRunningEvent` payload while preserving record ID, game ID, sequence, timestamp, and kind. The replacement carries the selected event-time `runnerID`, source, legal SB destination or CS out, and result. Event-time runner identity and order size are derived from accepted history for display and validation rather than added to the durable payload. Replay derives bases, outs, score, half-inning, active batter/count, and the batting projector derives R/SB/CS with no RBI; no schema migration is required.

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
Slice 6 completed-play deletion accepts the result component only when replay pairs it with an accepted In Play pitch for the same event-time opponent batter. Confirmation names both records; staging and saving remove the exact pair rather than cascading to unrelated history.

### OffensivePitchEvent payload

- `batter` event-time player identity and batting-order slot
- `battingOrderSize`
- `result`

Slice 6 Undo accepts non-terminal tracked-team Ball, Called Strike, Swinging Strike, and Foul records. Removing one reconstructs the prior offensive count while preserving the surviving event-time batter context, batting-order size, and unchanged batting projection.
Slice 6 earlier tracked-team pitch editing replaces only `result`. The persisted event-time batter identity, lineup slot, batting-order size, and record envelope are reused when encoding the candidate, so current lineup state cannot transfer the pitch to another player. Full replay validates the event-time count and every later batter transition before atomic Save.
Slice 6 earlier tracked-team pitch deletion removes only the selected `OffensivePitchEvent`. Every survivor retains its stable record ID, game ID, sequence number, timestamp, event-time player identity, lineup slot, and batting-order size. The sequence gap remains durable, full replay rebuilds the count and batting projection, and Save stays unavailable while a downstream event is rejected.

### OffensivePlateAppearanceEvent Undo

When the latest record is a completed tracked-team plate appearance, Undo removes that one authoritative record. Full replay restores its event-time batter and batting-order progression, prior count, bases, score, outs, and half-inning. Reprojecting the surviving events removes exactly that plate appearance's player-attributed PA, AB, hit classification, run, RBI, BB, HBP, or SO values.

### OffensiveBaseRunningEvent Undo

When the latest record is SB or CS, Undo removes that one authoritative record. The candidate resolves the runner's event-time identity from the accepted history that placed the player on base and confirms the source base, destination or out, result, and sequence. Full replay restores the runner to the prior base, removes an SB/CS and any steal-of-home run attribution, restores the prior half-inning after a third-out CS, and leaves the active batter, count, and plate-appearance progression unchanged.

## Derived—not persisted as competing truth

`GameState` is reconstructed from ordered events and currently contains inning/half, outs, count, score, bases, opponent batting slot, and pitch totals.

Future box scores and season statistics should likewise be projections, not independently edited counters.
