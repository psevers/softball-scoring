# Test Matrix

## Pitch/count regression

- 0/1/2 ball progression.
- Fourth ball completes BB.
- 0/1/2 strike progression.
- Third called/swinging strike completes K.
- Two-strike foul stays at two live strikes and increments pitch strike count.
- HBP total-only pitch classification.
- Ball In Play increments one pitch and enters pending-result state.
- Another pitch while pending is rejected/ignored.

## Base occupancy matrix for Ball In Play

Exercise outcome confirmation from all eight starting base states:

1. Empty
2. 1B
3. 2B
4. 3B
5. 1B + 2B
6. 1B + 3B
7. 2B + 3B
8. Loaded

Across representative:

- 1B
- 2B
- 3B
- HR
- E
- FC
- one-out batted outs
- Sac Fly / Sac Bunt
- Double Play

## Movement invariants

- Every occupied runner + batter appears exactly once.
- Missing runner rejected.
- Unexpected runner rejected.
- Duplicate source rejected.
- Second cannot finish at first.
- Third cannot finish at first/second.
- Two runners cannot finish at same base.
- Runner may hold current base.
- Batter may be out after credited hit while attempting extra base.

## Outs and inning boundary

- Play may record zero outs.
- One out adds one.
- DP adds exactly two.
- Play cannot create >3 inning outs.
- Third out clears bases/count and advances half.
- Sacrifice credit rejected when starting with two outs.

## Third-out runs

- Home touch + third out requires explicit counted-run quantity.
- Counted run quantity must be 0...home touches.
- RBI cannot exceed counted runs.
- Zero runs count on force-style third out.
- Timing play can count one of multiple apparent home touches.
- Third-out score applied before inning transition and survives replay.

## Persistence/replay

- Encode/decode Ball In Play payload round-trip.
- Relaunch while pending Ball In Play returns to outcome selection state.
- Relaunch after completed play restores score, bases, outs, batter and pitch totals.
- Malformed/duplicate sequence history is rejected and scoring pauses.

## Game setup

- Nine-player batting order with nine regulation defenders is accepted.
- 11–13-player batting orders with exactly nine defenders and batting-only entries are accepted.
- Duplicate players, missing/duplicate regulation positions, more than nine defenders, and a pitcher not assigned P are rejected.
- Full batting order and defensive assignments survive persistence.
- Innings-based and time-limited formats survive persistence.
- Timed status reaches expiration without silently finalizing the game.
