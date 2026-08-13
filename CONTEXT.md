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

## Defensive pitch deletion

A staged removal of one earlier defensive pitch. The candidate timeline replays without that exact record; Save remains unavailable when the removal invalidates a downstream record. A valid save preserves every surviving record's identity, sequence, and timestamp, including the deleted sequence gap.
