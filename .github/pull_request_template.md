## What changed

Describe the vertical user outcome, not just the files changed.

## Evidence

- [ ] Build passes
- [ ] Unit/scenario tests pass
- [ ] Simulator/manual validation completed where applicable
- [ ] Screenshots/video attached for UI changes

## Adversarial review — required before merge

Reviewer: act as if this PR contains a subtle production bug. Try to break it; do not merely confirm the happy path.

### Correctness and invariants
- [ ] Invalid/partial state attempted
- [ ] Boundary conditions attempted
- [ ] Persistence/relaunch behavior considered
- [ ] Existing game data cannot be silently corrupted
- [ ] Derived state is not persisted as a competing source of truth

### Scoring-specific hostile checks (when applicable)
- [ ] Third-out and run-ordering cases
- [ ] Bases occupied / forced runner conflicts
- [ ] Two-strike foul behavior
- [ ] Walk/HBP/strikeout terminal count behavior
- [ ] Pitch-count reconciliation
- [ ] Undo/replay after the changed event
- [ ] Editing an earlier event and replaying downstream state
- [ ] Pitching change / inherited-runner attribution

### UX failure modes
- [ ] Accidental double tap / repeated action considered
- [ ] User can recover when they fall behind live play
- [ ] Destructive actions are reversible or confirmed
- [ ] 44pt minimum target remains intact
- [ ] Outdoor legibility / contrast considered on scoring surfaces

## Findings

List every adversarial finding and resolution. Use `Accepted risk:` only when the risk is deliberate and documented.

## Merge gate

- [ ] `PR Fast Verification` is green
- [ ] `Exhaustive UI Evidence` is not required, or the successful pre-merge run is linked
- [ ] No unresolved P0/P1 adversarial findings
- [ ] Required regression tests added
- [ ] `docs/CURRENT_STATE.md` updated when architecture/state changed
- [ ] Adversarial reviewer approves
