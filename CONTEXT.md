# Domain Language

## Batting order

The ordered list of unique roster players eligible to bat in a game. Its length is variable and may exceed nine.

## Defender

A batting-order player assigned one of the nine regulation defensive positions at game start. Exactly nine defenders are required.

## Batting-only player

A player included in the batting order without a defensive assignment.

## Innings-based game

A game configured with a regulation inning count.

## Time-limited game

A game configured with a duration in minutes. Reaching the limit informs the scorekeeper; it does not automatically finalize the game.

## Tracked batter

The roster player expected to complete the tracked team's current plate appearance. Historical plate appearances identify this player by both player ID and the persisted batting-order slot used at the time.

## Batting-order slot

The one-based position of a player in a game's persisted batting order. The next slot wraps using that game's actual lineup length rather than assuming nine batters.

## Event-time batting order

The batting-order size recorded with a plate appearance or offensive pitch when it occurred. Historical replay uses this context, not a later mutable lineup, to validate the batter and advance the slot.

## Offensive base-running event

A stolen-base or caught-stealing attempt recorded independently of a plate appearance. It changes runner position, outs, or score without advancing the tracked batter.

## Batting projection

Player-attributed batting totals derived from the ordered game-event history. These totals are never authoritative mutable records.

## Authoritative game snapshot

A fresh, game-scoped projection containing the ordered event records, replayed game state, batting projection, and Play History. Live scoring and history consume the same snapshot boundary.

## Play History

A read-only scorebook projection over the authoritative event timeline. It groups records by event-time half-inning and logical plate appearance while retaining each component record.

## Problem entry

A visible Play History entry for an unknown kind, malformed payload, invalid or duplicate sequence, semantic replay rejection, or event-addressable batting-projection failure. Problem entries preserve the record's chronological position and decoded context when available instead of crashing or disappearing.

## Undo candidate

The latest persisted scoring action when it is an eligible defensive Ball, Called Strike, Swinging Strike, Foul, HBP, completed Ball In Play result, tracked-team count pitch, completed tracked-team plate appearance, or tracked-team SB/CS event. A terminal-pitch candidate records the plate appearance it completed; a Ball In Play result candidate identifies the preceding counted pitch that will remain; tracked-team candidates retain the event-time player identity and batting-order size. A completed tracked-team plate-appearance candidate also carries its result, runner movements, runs, and RBI for exact confirmation. An SB/CS candidate identifies the event-time runner, source base, destination or out, result, and sequence. Every candidate retains the expected game timeline so a moved or stale action cannot be removed.

## Correction boundary

The main-actor persistence boundary that freshly fetches one game's event records, validates a candidate timeline through replay and batting projection, and saves the event-history change atomically. Derived game state is never reverse-mutated.

## Correction session

An in-memory candidate timeline tied to an exact durable record revision. It may begin from already-locked history, retains every staged edit or deletion by record identity, replays the complete candidate after each change, identifies the first remaining invalid record, and can save only when the whole timeline and batting projection are clean.

## Locked-history repair

An explicit correction session for one or more existing Play History problems. Known decodable events use their supported event editor or deletion control; unknown kinds, malformed payloads, and invalid or duplicate sequence records allow deletion of only the exact problem record. Each staged repair preserves durable history until one clean atomic save, without rewriting, reordering, renumbering, detaching, or cascade-deleting survivors.

## Unreadable record deletion

A deletion-only recovery for one Play History problem entry whose event kind is unknown or whose payload cannot decode. Confirmation identifies the exact record and explicitly refuses to guess or edit its missing meaning. Staging removes only that record from an in-memory candidate; a valid atomic save preserves every survivor envelope and sequence gap, while any remaining replay or projection rejection keeps Save unavailable.

## Pitch-count reconciliation

An appended authoritative event that applies signed total, ball, and strike adjustments to one stable pitcher identity. The difference between the total adjustment and its ball-plus-strike adjustments is unclassified. It may carry a related-play reference to one earlier completed defensive plate appearance in the same game. Replay changes only that pitcher's derived totals; the live count and every non-pitch game value remain unchanged.

## Related-play reference

A stable reconciliation link containing the completed defensive play's record ID, game ID, chronological sequence, event kind, and canonical payload-revision digest. Replay accepts the link only when it exactly matches an earlier readable, accepted completed defensive play. If that play is edited or deleted, the reconciliation becomes an explicit correction problem until the scorer re-associates it, deliberately removes the association, or explicitly deletes a reconciliation whose signed adjustment is no longer valid for the candidate pitcher totals.

## Defensive pitch edit

A staged replacement of one earlier non-terminal defensive Ball, Called Strike, Swinging Strike, or Foul. The edit retains the pitch's event-time inning, half, opponent batting slot, pitcher, record identity, sequence, and timestamp while replaying the complete candidate timeline before Save.

## Tracked-team pitch edit

A staged replacement of one earlier tracked-team Ball, Called Strike, Swinging Strike, or Foul. The edit retains the event-time player identity, batting-order slot and size, record identity, game, sequence, and timestamp. Full replay validates the replacement against the count and tracked batter that existed at that sequence; a current lineup player or later occupant of the same slot cannot replace that identity.

## Tracked-team pitch deletion

A staged removal of one earlier tracked-team Ball, Called Strike, Swinging Strike, or Foul. Confirmation names the event-time player, batting-order slot and size, result, and sequence. Full replay reconstructs the count and player-attributed projection from the surviving timeline; Save remains unavailable until every downstream event satisfies its event-time batter and count contract.

## Tracked-team plate-appearance edit

A staged replacement of one earlier completed tracked-team plate appearance, including a multi-out or third-out play. The scorer keeps the persisted event-time batter, batting-order slot and size, record identity, game, sequence, and timestamp while reconfirming the result, exactly one legal destination for the batter and every event-time runner, every counted home touch, RBI, and any force/batter-runner or timing-play third-out classification. Full replay rebuilds score, bases, outs, count, the next tracked batter across the half-inning transition, and player-attributed batting lines; any rejected downstream plate appearance must be explicitly repaired in the same atomic correction session.

## Tracked-team logical-play deletion

A staged removal of every tracked-team count pitch and the terminal plate-appearance result in one completed logical play. Confirmation names each component sequence and summary. Full replay removes the play's result, runs, RBI, and batting attribution while preserving unrelated base-running events and every surviving record envelope; any rejected downstream record must be explicitly repaired before the correction session can save atomically.

## Tracked-team base-running edit

A staged replacement of one earlier SB or CS event. The editor derives every eligible runner, source base, identity, lineup slot, and batting-order size from the event-time replay state, then accepts a legal SB destination or CS out. Full replay rebuilds score, bases, outs, half-inning, active batter/count, and player-attributed R/SB/CS without adding RBI; any rejected downstream SB/CS must be explicitly repaired before the correction session can save atomically.

## Defensive pitch deletion

A staged removal of one earlier defensive pitch. The candidate timeline replays without that exact record; Save remains unavailable when the removal invalidates a downstream record. A valid save preserves every surviving record's identity, sequence, and timestamp, including the deleted sequence gap.

## Defensive Ball In Play edit

A staged replacement of one completed defensive Ball In Play result, including a multi-out or third-out play. The preceding In Play pitch remains counted while the scorer confirms the corrected outcome, every event-time runner destination, every legally counted home touch, RBI, and any force/batter-runner or timing-play third-out classification. A valid save preserves the result record's identity, sequence, and timestamp and rebuilds every later score, base, out, batter, and pitcher state from the candidate timeline.

## Defensive logical-play deletion

A staged removal of the paired In Play pitch and completed defensive Ball In Play result as one explicit correction. The confirmation names both record sequences, individual component deletion remains separate, and full candidate replay returns to the state before the In Play pitch. A valid save removes exactly the pair while preserving every survivor's identity, sequence, timestamp, and sequence gaps.
