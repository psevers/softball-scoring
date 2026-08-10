# Scoring Rules

This is the canonical product interpretation of scoring behavior. Tests should mirror it.

## Game baseline

- Regulation default: 7 innings.
- Top: away team bats; Bottom: home team bats.
- Three outs advance the half-inning and clear the bases.
- MVP starting defense: P, C, 1B, 2B, 3B, SS, LF, CF, RF.
- DP/FLEX, re-entry, and courtesy-runner rules are deferred until the basic scorer survives real games.

## Pitch-level defensive events

Supported:

- Ball
- Called Strike
- Swinging Strike
- Foul
- Ball In Play
- Hit By Pitch

Every pitch increments total pitch count once.

Pitch-stat classification:

- Ball → pitch ball.
- Called Strike → pitch strike.
- Swinging Strike → pitch strike.
- Foul → pitch strike, including two-strike foul.
- Ball In Play → pitch strike.
- HBP → total only; neither displayed pitch ball nor strike.

### Live count

- Fourth ball completes BB.
- Third called/swinging strike completes K.
- Two-strike foul leaves live strikes at two.
- HBP awards first immediately.
- Ball In Play does **not** complete the PA by itself; it pauses pitch entry until the resulting play is recorded.

## BB/HBP forced advancement

Only forced runners advance. Bases-loaded BB/HBP scores exactly one run.

## Ball in play

Supported result labels:

- 1B, 2B, 3B, HR
- E, FC
- GO, FO, LO, PO
- Sac Bunt, Sac Fly
- Double Play

The result label never silently determines all baserunning. The UI proposes destinations; the scorer confirms the final destination for the batter and every existing runner.

Destination options are 1B / 2B / 3B / Home / Out, constrained so an existing runner cannot move backward and two runners cannot finish on the same base.

A hit label describes the credited batted-ball result; the batter may end farther than the credited base or be retired trying to advance.

## Outs

The number of `Out` destinations on the play is the number of outs recorded by that play.

- Inning total cannot exceed three.
- Double Play requires exactly two `Out` destinations.
- Ordinary GO/FO/LO/PO/Sac requires batter out and at least one out on play.
- Sacrifice bunt/fly is invalid when the play begins with two outs.

Triple-play-specific UX is not yet a dedicated result label.

## Runs on a third out

A runner touching home and a legally scored run are not always the same thing.

If a play both creates the third out and has one or more `Home` destinations, the scorer must provide `thirdOutRunsCounted` in the range `0...homeTouches`.

Examples:

- Force/batter-runner third out: generally `0`.
- Timing play: count only runners who crossed home before the third out.
- If two runners touch home but only one crossed before the third out, record `1`.

The reducer increments the game score by exactly this number, then advances the inning.

## RBI placeholder

Slice 4 stores an explicit RBI number with the play so later stat projection has source data. RBI may never exceed the number of legally counted runs on the play. More nuanced automatic RBI suggestion rules can improve later without changing the event contract.

## Opponent batting order

Opponent slots rotate 1...9. Completing a PA advances the slot; 9 wraps to 1.

## Event invariants

- Persisted events are authoritative history.
- Sequence numbers are positive and unique.
- Same ordered valid history → same `GameState`.
- Pitch must match current opponent batter and current pitcher contract.
- Defensive events cannot apply while tracked team bats.
- A pending Ball In Play result blocks further pitch events.
- Every runner present at play start must appear exactly once in the play payload.
- Unreadable/invalid history pauses new scoring instead of silently mutating around corruption.

## Known MVP scoring gaps

Still required before game-complete MVP:

- tracked-team offensive PAs/player attribution,
- standalone SB/CS/WP/PB/advance/basepath-out events,
- undo/edit/pitch-count correction,
- pitching changes,
- dropped-third-strike flow,
- detailed fastpitch substitutions/DP-FLEX.
