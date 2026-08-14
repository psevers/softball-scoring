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

## Tracked-team offensive entry

- Ball, called strike, swinging strike, and foul are persisted with the displayed tracked batter and event-time batting-order size.
- Fourth ball completes a player-attributed walk; third called/swinging strike completes a player-attributed strikeout.
- A two-strike foul leaves the live count at two strikes.
- Quick Walk, HBP, Strikeout, and Home Run remain available and produce the same plate-appearance events as normal entry.
- Opponent-pitcher statistics are not tracked in this slice.
- Undo of the latest non-terminal tracked-team pitch removes its event record only. Full replay restores the prior count and event-time batter context without changing batting projection or any pitcher total.
- Undo of the latest completed tracked-team plate appearance removes its event record only. Full replay restores count, bases, score, outs, half-inning, and event-time batting-order progression; batting projection drops exactly that play's player attribution.

## Stolen base / caught stealing

- SB advances one identified runner exactly one base, including third to home.
- CS removes one identified runner and adds one out.
- Neither result advances the current batter or completes a plate appearance.
- A steal of home credits the runner with both SB and R; no RBI is credited.
- A third-out CS advances the half-inning and preserves the next tracked batter.
- Undo of the latest SB/CS record restores the identified runner to the source base through full replay. It removes only that runner's SB/CS attribution and any steal-of-home run, restores the prior offensive half after a third-out CS, and leaves the active batter and count unchanged.

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
- Undo latest eligible action removes only the latest persisted defensive Ball, Called Strike, Swinging Strike, Foul, HBP, completed Ball In Play result, tracked-team count pitch, completed tracked-team plate appearance, or tracked-team SB/CS after exact-timeline validation. Replaying the surviving timeline restores defensive count and pitcher totals; for ball four, strike three, and HBP it also restores batter slot, runners, score, outs, and half-inning together. Undoing a completed Ball In Play removes its result record only, preserves the counted In Play pitch, and restores the pre-result bases, outs, score, opponent batter slot, pitcher totals, and pending-result state. Undoing a tracked-team pitch restores the offensive count and event-time batter context without changing batting projection or pitcher totals. Undoing a completed tracked-team plate appearance restores its entire pre-play game state and removes its player attribution from the batting projection. Undoing SB/CS restores its event-time runner and removes only that attempt's base-running attribution while preserving active plate-appearance progression. No derived value is reverse-mutated.
- Editing an earlier non-terminal defensive count pitch stages one supported replacement in memory, replays and reprojects the full timeline, and disables Save at the first invalid later record. A valid Save updates only that pitch payload/kind while preserving record identity, game, sequence, and timestamp; no derived value is reverse-mutated.
- Editing an earlier tracked-team count pitch accepts only a replacement result and rebuilds the event from its persisted player identity, lineup slot, and event-time batting-order size. Replay validates the result against the count and tracked batter at that sequence, preserves every later batter transition and player-attributed batting line, and requires explicit staged repair for an invalid downstream offensive record.
- Deleting an earlier tracked-team count pitch stages removal of only that event record. Confirmation uses its event-time player, batting slot and order size, result, and sequence. Full replay reconstructs the active count, tracked batter, and every surviving player-attributed result. A downstream walk or strikeout that originally completed a three-ball or two-strike count must still satisfy that saved count contract after correction; any invalid downstream record is never rewritten or skipped and keeps Save disabled until explicitly repaired.
- Editing an earlier completed tracked-team plate appearance is limited to plays with no counted run that do not make the third out. Walk, HBP, strikeout, single, double, triple, error, fielder's choice, ordinary out, sacrifice bunt, and double-play shapes reuse the ordinary offensive validator. The persisted batter identity and order size cannot change, and the batter plus every occupied event-time runner must appear exactly once with a legal destination. Missing, duplicate, unexpected, backward, passing, colliding, excess-out, illegal-sacrifice, scoring, third-out, and result/destination mismatches are rejected. A valid replacement preserves the record envelope and full replay rebuilds count, bases, outs, next batter, downstream validity, and player-attributed batting projection; rejected later plate appearances require explicit staged repair before the batch can save atomically.
- Editing an eligible completed defensive Ball In Play reuses the ordinary runner-movement validator. The scorer confirms the batter and every occupied event-time runner exactly once, including every explicit out source on a multi-out play, then assigns RBI no greater than legally counted runs. A non-third-out play counts every home touch. A third-out play with a home touch requires force/batter-runner or timing classification and an explicit counted-run quantity; force/batter-runner outs count zero, while timing plays may count only legal pre-out touches. Missing, duplicate, unexpected, backward, passing, colliding, excess-out, outcome-inconsistent, ambiguous/contradictory classification, illegal run-count, and excess-RBI proposals are rejected. Candidate replay scores legal runs before advancing the half-inning, clearing bases/count/outs, and retaining future batter progression. The counted In Play pitch and pitcher total do not change.
- Deleting a completed defensive logical play removes exactly its paired In Play pitch and result records. Full replay restores the pre-pitch count, bases, outs, score, batter slots, and pitcher totals; unrelated earlier pitches and later events survive unless the scorer explicitly repairs a rejected downstream record.
- Sequence numbers are positive and unique.
- Same ordered valid history → same `GameState`.
- Pitch must match current opponent batter and current pitcher contract.
- Defensive events cannot apply while tracked team bats.
- Offensive events cannot apply while the opponent bats.
- Offensive pitch and PA writes must match the batter displayed by the caller and authoritative replay.
- Historical offensive pitch/PA replay uses event-time batter and lineup-size context, not the mutable current lineup.
- Once an offensive pitch starts a count, every later pitch and the completing PA must carry the same event-time batter identity and lineup size; mismatched history is rejected.
- A pending Ball In Play result blocks further pitch events.
- Every runner present at play start must appear exactly once in the play payload.
- Unreadable/invalid history pauses new scoring instead of silently mutating around corruption.

## Known MVP scoring gaps

Still required before game-complete MVP:

- standalone WP/PB/manual advance/basepath-out events,
- remaining scoring-run and half-inning-ending correction workflows,
- pitching changes,
- dropped-third-strike flow,
- detailed fastpitch substitutions/DP-FLEX.
