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
