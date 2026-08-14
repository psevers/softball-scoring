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

A visible Play History entry for an unknown kind, malformed payload, invalid sequence, or semantically rejected record. Problem entries preserve the record's chronological position instead of crashing or disappearing.

## Undo candidate

The latest persisted scoring action when it is an eligible defensive Ball, Called Strike, Swinging Strike, Foul, HBP, completed Ball In Play result, tracked-team count pitch, completed tracked-team plate appearance, or tracked-team SB/CS event. A terminal-pitch candidate records the plate appearance it completed; a Ball In Play result candidate identifies the preceding counted pitch that will remain; tracked-team candidates retain the event-time player identity and batting-order size. A completed tracked-team plate-appearance candidate also carries its result, runner movements, runs, and RBI for exact confirmation. An SB/CS candidate identifies the event-time runner, source base, destination or out, result, and sequence. Every candidate retains the expected game timeline so a moved or stale action cannot be removed.

## Correction boundary

The main-actor persistence boundary that freshly fetches one game's event records, validates a candidate timeline through replay and batting projection, and saves the event-history change atomically. Derived game state is never reverse-mutated.

## Correction session

An in-memory candidate timeline tied to an exact durable record revision. It retains every staged edit or deletion by record identity, replays the complete candidate after each change, identifies the first invalid downstream record, and can save only when the whole timeline and batting projection are clean.

## Defensive pitch edit

A staged replacement of one earlier non-terminal defensive Ball, Called Strike, Swinging Strike, or Foul. The edit retains the pitch's event-time inning, half, opponent batting slot, pitcher, record identity, sequence, and timestamp while replaying the complete candidate timeline before Save.

## Tracked-team pitch edit

A staged replacement of one earlier tracked-team Ball, Called Strike, Swinging Strike, or Foul. The edit retains the event-time player identity, batting-order slot and size, record identity, game, sequence, and timestamp. Full replay validates the replacement against the count and tracked batter that existed at that sequence; a current lineup player or later occupant of the same slot cannot replace that identity.

## Tracked-team pitch deletion

A staged removal of one earlier tracked-team Ball, Called Strike, Swinging Strike, or Foul. Confirmation names the event-time player, batting-order slot and size, result, and sequence. Full replay reconstructs the count and player-attributed projection from the surviving timeline; Save remains unavailable until every downstream event satisfies its event-time batter and count contract.

## Tracked-team plate-appearance edit

A staged replacement of one earlier completed tracked-team plate appearance that did not end the half-inning. The scorer keeps the persisted event-time batter, batting-order slot and size, record identity, game, sequence, and timestamp while reconfirming the result, exactly one legal destination for the batter and every event-time runner, every counted home touch, and RBI. Full replay rebuilds score, bases, outs, count, next batter, and player-attributed batting lines; any rejected downstream plate appearance must be explicitly repaired in the same atomic correction session.

## Defensive pitch deletion

A staged removal of one earlier defensive pitch. The candidate timeline replays without that exact record; Save remains unavailable when the removal invalidates a downstream record. A valid save preserves every surviving record's identity, sequence, and timestamp, including the deleted sequence gap.

## Defensive Ball In Play edit

A staged replacement of one completed defensive Ball In Play result, including a multi-out or third-out play. The preceding In Play pitch remains counted while the scorer confirms the corrected outcome, every event-time runner destination, every legally counted home touch, RBI, and any force/batter-runner or timing-play third-out classification. A valid save preserves the result record's identity, sequence, and timestamp and rebuilds every later score, base, out, batter, and pitcher state from the candidate timeline.

## Defensive logical-play deletion

A staged removal of the paired In Play pitch and completed defensive Ball In Play result as one explicit correction. The confirmation names both record sequences, individual component deletion remains separate, and full candidate replay returns to the state before the In Play pitch. A valid save removes exactly the pair while preserving every survivor's identity, sequence, timestamp, and sequence gaps.
