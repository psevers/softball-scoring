# Softball Scoring — Laptop Handoff + Next Build Plan

Canonical repo: https://github.com/psevers/softball-scoring

Current implementation checkpoint:
- Vertical Slice 0 — Foundation
- Vertical Slice 1 — Team + Season + Roster
- Vertical Slice 2 — New Game + Lineup + Resume
- Vertical Slice 3 — Pitch-by-pitch defensive scoring
- Vertical Slice 4 — Ball in Play + Runner Movement + Runs + Outs

Latest generated package:
- `softball-scoring-window1-slice4.zip`

## Important Build Policy

No PR is considered merge-ready until it has passed an adversarial review.

The review must actively try to prove the implementation wrong.

For scoring-related PRs, reviewers must inspect:
- State corruption
- Replay determinism
- Persistence failures
- Pitch attribution
- Batter attribution
- Base collisions
- Third-out run ordering
- Forced vs timing plays
- Undo/edit consequences
- Invalid event payloads
- Stat projection regressions
- UI paths that can produce impossible game state

Every P0/P1 issue must be:
1. Fixed, or
2. Explicitly documented as accepted risk before merge.

## Visual Direction

The approved visual direction is:

**A real pencil-and-paper softball scorebook on an iPhone.**

Principles:
- Warm off-white paper background
- Subtle ruled/grid scorebook texture
- Pencil/graphite visual treatment
- Hand-drawn base diamonds
- Circled outs and handwritten-feeling annotations
- Scorebook-like tables and inning columns
- Native iOS interaction patterns underneath
- Large touch targets
- Strong outdoor readability
- No decorative treatment that slows scoring

The app should feel like a scorebook, but behave like software.

Forms and configuration screens may remain cleaner and more conventionally native than live scoring surfaces.

---

# Laptop Validation Checklist

Before building Slice 5:

## 1. Apply latest package

Unzip `softball-scoring-window1-slice4.zip` into the canonical repo.

Be careful not to accidentally nest the project one directory too deep.

## 2. Generate project

```bash
xcodegen generate
```

## 3. Open project

Open the generated Xcode project/workspace.

## 4. Build

Use a current iPhone simulator.

Suggested command:

```bash
xcodebuild \
  -scheme SoftballScoring \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  build
```

If the installed simulator name differs, select one available on the Mac.

## 5. Run tests

```bash
xcodebuild \
  -scheme SoftballScoring \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  test
```

## 6. Manual smoke test

Verify:

- App launches
- Games / Stats / Team navigation works
- Season persists
- Roster persists
- New game can be created
- Lineup can be configured
- Starting pitcher can be selected
- In-progress game resumes
- Defensive pitch buttons update count
- Two-strike foul does not strike out batter
- Four balls produces walk
- HBP advances batter
- Three outs changes half-inning
- Ball In Play enters play-resolution flow
- Runner destinations can be confirmed
- Runs and outs update
- Third-out behavior does not produce obviously incorrect runs
- Relaunch preserves the in-progress game

## 7. Fix all compile/runtime failures before new feature work

Do not begin Slice 5 on top of unresolved Xcode errors.

## 8. Commit checkpoint

Suggested commit:

```bash
git add .
git commit -m "feat: complete scoring foundation through ball-in-play"
git push
```

---

# Vertical Slice 5 — Offensive Scoring + Player Attribution

## Goal

Use the same scoring engine for our team's offensive half-innings and attribute every plate appearance to an actual roster player.

At the end of this slice, the app should be capable of scoring both halves of a game with correct batter identity.

## User-visible behavior

When our team comes to bat:

- Current hitter is selected automatically from the lineup
- Player name / jersey / position are visible
- The app advances through batting order automatically
- Batting order wraps correctly
- The scorebook surface displays the player's current game line
- Normal pitch tracking remains available
- Quick plate-appearance results remain available
- Ball-in-play flow remains identical to defensive scoring
- Runs and RBI are attributed to players

## Required domain work

Add reliable player attribution to scoring events.

Every offensive plate appearance must resolve to:
- `playerID`
- lineup slot
- inning
- pitcher/opponent context where required

Do not derive historical player identity solely from the current lineup after the fact.

A historical event must retain enough identity information to replay correctly after future lineup edits.

## Batting-order rules

Test:

- Every batter in the persisted lineup, including orders longer than nine
- Wrap the final batting-order slot → Batter 1 using the actual lineup length
- Half-inning ending early
- Next offensive inning resumes with correct next hitter
- Game reload preserves next hitter
- Undo third out restores correct batter progression
- Edit earlier play does not arbitrarily change unrelated lineup position

## Game batting projection

Track:

- PA
- AB
- R
- H
- 2B
- 3B
- HR
- RBI
- BB
- HBP
- SO
- SB
- CS

Derived values may be introduced now or later:
- AVG
- OBP
- SLG
- OPS

For Slice 5, correctness of counting stats matters more than presentation polish.

## AB vs PA rules to encode

At minimum:

Counts as PA:
- Hit
- Walk
- HBP
- Reached on error
- Fielder's choice
- Strikeout
- Sacrifice bunt
- Sacrifice fly
- Ordinary batted-ball out

Does not count as AB:
- Walk
- HBP
- Sacrifice bunt
- Sacrifice fly

Counts as AB:
- Hit
- Reached on error
- Fielder's choice
- Strikeout
- Ordinary non-sacrifice out

Confirm final conventions in `SCORING_RULES.md`.

## Slice 5 design outputs

### Offensive live scoring surface

Should look like a digital page in a pencil scorebook.

Display:

- Inning
- Score
- Outs
- Bases
- Batter
- Jersey number
- Defensive position
- Current game batting line
- Count
- Pitch controls
- Quick result controls
- Undo/history

### Batter card

Example:

```
#23 Davis — C
1 for 2
2B · RBI · R
```

Keep this compact.

### Batting-order strip

Optional design exploration:
- Current batter prominently shown
- Previous / on-deck batter subtly visible
- Avoid horizontally scrolling nine-player lineup during active scoring unless testing proves useful

---

# Vertical Slice 5 Adversarial Scenarios

## Attribution

1. Batter gets a single; ensure hit belongs to correct player.
2. Batter walks; PA and BB increment, AB does not.
3. Batter reaches on error; PA and AB increment, H does not.
4. Batter hits sacrifice fly; PA increments, AB does not.
5. Batter strikes out; PA, AB, SO increment.
6. Runner scores several batters later; run belongs to original runner.
7. RBI belongs to batter whose event caused the legal run.

## Batting order

8. A full trip through 9-player and 13-player orders advances every slot correctly.
9. The final batter in each order is followed by Batter 1.
10. Third out on Batter 5 means next inning begins with Batter 6.
11. Undo third out restores Batter 5 outcome and next-batter state.
12. Relaunch app mid-inning preserves current batter.

## Replay

13. Replaying same event stream produces same batter identity and stats.
14. Changing current roster metadata must not rewrite historical event identity.
15. Editing an earlier play must recalculate downstream stats deterministically.

## Runner attribution

16. Player A reaches base.
17. Player B advances A.
18. Player C drives A home.
19. Player A receives R.
20. Player C receives RBI if legally appropriate.

---

# Vertical Slice 6 — Undo + Play History + Correction Engine

## Goal

Make the app safe enough to trust during an actual game.

The scorer must be able to recover from mistakes without restarting the game.

## Core behavior

- Undo latest pitch
- Undo latest completed play
- View chronological play history
- Select a previous event
- Edit it
- Delete it
- Replay all downstream state
- Correct pitch count
- Preserve deterministic state

## Design direction

The history UI can resemble handwritten scorebook notes in the margin.

Example:

```
T3
Davis — 2B, Smith scored
Miller — K
Jones — BB
```

Use pencil-style annotations while retaining ordinary iOS selection/edit affordances.

## Critical rule

**Undo is not a pile of reverse mutations.**

The preferred model is:

```
Event log
  -> remove / replace event
  -> replay
  -> derive state
```

This is central to long-term correctness.

## Adversarial scenarios

1. Undo a ball.
2. Undo a strike.
3. Undo strike three.
4. Undo ball four.
5. Undo HBP.
6. Undo single with runners advancing.
7. Undo HR.
8. Undo third out.
9. Undo half-inning transition.
10. Undo play containing two outs.
11. Edit runner destination from third → home to third → out.
12. Edit a hit to an error.
13. Edit a hit to an out.
14. Delete a previous scoring play.
15. Recalculate every later base state.
16. Correct pitch count after missed pitch.
17. Correct pitch count after pitcher change.
18. Relaunch after an edit and verify same state.

---

# Future Slice 7 — Pitching Changes

Important edge cases to preserve for later:

- Pitching change between innings
- Pitching change mid-PA (decide MVP policy explicitly)
- Pitching change with runners aboard
- Inherited runners
- Runs charged to responsible pitcher
- Pitch counts remain with outgoing pitcher
- New pitcher starts their own pitch total
- Stat lines survive replay/edit

A decision record should be created before implementing mid-PA pitching changes.

---

# Scoring Edge Cases To Resolve Before MVP

These should become explicit rules, not assumptions.

## Third-out run scoring

Distinguish:
- Force out
- Batter-runner out before reaching first
- Timing play

Runs do not score when the third out is a force out or batter-runner is retired before reaching first.

Timing plays require explicit ordering/count of legal runs before the third out.

## Dropped third strike

Fastpitch rules can depend on:
- Number of outs
- First-base occupancy
- Rule set / age level

Do not improvise this rule.

Add explicit support in the fastpitch-rules expansion unless it becomes required during real-game testing.

## Courtesy runners

Defer until fastpitch rules expansion unless the scorer cannot complete real games without it.

## DP/FLEX

Defer until basic game scoring is validated.

The eventual model must avoid assuming "nine batting slots == nine defensive players."

## Re-entry

Defer but keep substitutions/event identity architecture compatible with it.

## International tiebreaker

Likely future requirement:
- Runner placed on second to begin extra inning

Do not add until core scoring works.

## Earned runs

ER attribution can become complicated around errors.

For early MVP:
- Track runs accurately first.
- Define earned-run calculation carefully before claiming advanced pitching accuracy.

---

# Design Test Plan

When running the app on a real iPhone, test the scorebook visual direction under actual game-like conditions.

Evaluate:

- Direct sunlight readability
- One-handed use
- Tap targets with attention on field rather than screen
- Whether pencil contrast is too faint
- Whether grid texture adds clutter
- Whether handwritten typography is readable for numbers
- Whether bases can be understood at a glance
- Whether outs/count stand out enough
- Whether active controls look tappable
- Whether undo is easy to find but hard to hit accidentally

The visual theme should never obscure state.

Use system typography for dense/statistical values if handwritten styling harms legibility.

---

# Pre-Merge Adversarial Review Template

Use this on every PR.

## Correctness

- What assumptions does this code make?
- What happens with malformed or stale persisted data?
- Can the user generate impossible state?
- Is event replay deterministic?
- Are identities persisted rather than inferred unsafely?
- Can ordering be ambiguous?
- Are downstream projections recalculated correctly?

## Scoring-specific

- Third out?
- Force play?
- Timing play?
- Multiple runs?
- Multiple outs?
- Bases loaded?
- Batter/runner identity?
- Pitcher identity?
- Batting-order wrap?
- Pitch count?
- Undo/edit?
- Relaunch/replay?

## Persistence

- Kill app mid-game.
- Relaunch.
- Does state match?
- Are partial writes possible?
- Are decode failures visible rather than silently discarded?

## UI

- Can rapid taps double-submit?
- Can controls be used while a play is unresolved?
- Can the user accidentally score the wrong half-inning?
- Is destructive editing reversible/confirmed?
- Are touch targets large enough?

## Tests

- Does every discovered P0/P1 bug get a regression test?
- Are tests checking behavior rather than implementation details?
- Is there at least one hostile scenario beyond the happy path?

## Decision

PR may merge only when:
- CI is green
- Xcode build/test is green
- No unresolved P0
- No unresolved P1 unless explicitly accepted
- Adversarial review notes are committed

---

# Next Work Session

Once the laptop validation is green:

1. Commit Slice 4 checkpoint.
2. Start Slice 5.
3. Implement offensive batter/player attribution.
4. Add batting stat projector.
5. Build offensive scorebook UI.
6. Add hostile scenario tests.
7. Run adversarial review.
8. Do not merge until Xcode/CI passes.
9. Then begin Slice 6 correction engine.

The first major usability milestone is after Slice 6:

**A complete game can be scored, attributed to real players, and corrected safely.**
