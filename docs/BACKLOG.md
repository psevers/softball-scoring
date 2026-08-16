# Backlog

## Completed vertical slices

- Slice 0 — Foundation / app shell / docs / test targets.
- Slice 1 — Team + season + roster.
- Slice 2 — New game + lineup + starting pitcher + resume.
- Slice 3 — Defensive pitch-by-pitch scoring / event reducer.
- Slice 4 — Ball In Play + runner confirmation + runs + outs.
- Slice 5 — Full tracked-team offensive scoring and player attribution.
- Slice 5.5 — Approved scorebook visual alignment and evidence matrix.
- Slice 6 — Play History, Undo, correction, pitch reconciliation, locked-history repair, and cold-relaunch proof.

## Field-feedback fixes after Slice 4

- Variable batting orders with exactly nine independent defensive assignments.
- Scrollable lineup setup with a persistently reachable Start Game action.
- Innings-based or 30–90 minute wheel-selected game setup, persisted format display, and informational countdown.

## Next

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

- Wild pitch.
- Passed ball.
- Manual advance / score / out on basepaths.
- Dropped third strike.

## Maintenance follow-up awaiting issue publication

- Replace `GameEventCorrectionSession`'s parallel staged-mutation arrays and duplicated preview/save interpreters with one typed mutation collection consumed by both paths.
- Split the multi-workflow `DefensivePitchEditView.swift` correction UI by workflow family around its existing coordinator and section seams.

These P3 review findings are non-blocking for Slice 6. Publish them as GitHub issues before merge once external publication is explicitly authorized.

## Post-MVP / field-evidence candidates

- DP/FLEX.
- Re-entry rules.
- Courtesy runners.
- International tiebreaker runner.
- Detailed fielding notation/putouts/assists.
- CSV/share export.
- iCloud backup/sync.
- Spray charts / pitch location / pitch type / velocity.
