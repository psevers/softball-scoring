# Backlog

## Completed vertical slices

- Slice 0 — Foundation / app shell / docs / test targets.
- Slice 1 — Team + season + roster.
- Slice 2 — New game + lineup + starting pitcher + resume.
- Slice 3 — Defensive pitch-by-pitch scoring / event reducer.
- Slice 4 — Ball In Play + runner confirmation + runs + outs.

## Field-feedback fixes after Slice 4

- Variable batting orders with exactly nine independent defensive assignments.
- Scrollable lineup setup with a persistently reachable Start Game action.
- Innings-based or time-limited game setup, persisted format display, and informational countdown.

## Next

### Slice 5 — Full offensive scoring

- Current tracked-team batter from lineup.
- Player-attributed PA results.
- Offensive runner IDs use player IDs rather than opponent slots.
- Batting stat projection inputs.
- Batting-order rollover.
- Quick PA scoring when pitch-level tracking is unavailable/not desired.

### Slice 6 — Recovery / trust

- Undo latest event.
- Play history.
- Edit/delete prior play and full replay.
- Manual pitch-count correction.
- Reconcile a quick-scored PA with pitch total.

### Slice 7 — Pitching changes

- Current pitcher state derived from events.
- Mid-inning/between-inning changes.
- Pitch counts and pitching lines by appearance.
- Inherited runner attribution groundwork.

### Slice 8 — Box score / finalize

- Line score.
- Batting box score.
- Pitching box score.
- Finalization/reopen.

### Slice 9 — Season stats

- Batting and pitching projections across final games.
- AVG / OBP / SLG / OPS / ERA / WHIP / strike % / pitches per inning.

### Slice 10 — Real-game hardening

- Seven-inning field test.
- One-handed/outdoor-readability review.
- Tap-count and recovery friction review.

## MVP gaps not yet assigned to a dedicated slice

Must be scheduled before declaring game-complete MVP:

- Stolen base.
- Caught stealing.
- Wild pitch.
- Passed ball.
- Manual advance / score / out on basepaths.
- Dropped third strike.
- Quick-scoring pitch-count reconciliation.

## Post-MVP / field-evidence candidates

- DP/FLEX.
- Re-entry rules.
- Courtesy runners.
- International tiebreaker runner.
- Detailed fielding notation/putouts/assists.
- CSV/share export.
- iCloud backup/sync.
- Spray charts / pitch location / pitch type / velocity.
