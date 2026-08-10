# Slice 2 Adversarial Review

Scope: New Game → lineup → starting pitcher → persist/resume shell, plus adoption of the scorebook visual direction and mandatory review gate.

Reviewer stance: assume a setup bug can poison all downstream scoring data.

## Findings

### P1 — Save failure silently dismissed the setup flow — RESOLVED

**Attack:** Force `ModelContext.save()` to fail.

**Before:** `try?` discarded the error and the sheet dismissed, making the user believe the game started even if persistence failed.

**Fix:** Use `do/catch`, rollback on failure, retain the flow, and show an error alert. The game only dismisses after a successful save.

### P1 — Nine players could start with missing/duplicate defensive positions — RESOLVED

**Attack:** Add nine unique players, leave positions empty or assign the same position twice.

**Before:** validation checked only player uniqueness and pitcher membership.

**Fix:** setup now requires exactly the nine regulation defensive positions once each: P, C, 1B, 2B, 3B, SS, LF, CF, RF. `UTIL` remains a roster default but is not a valid regulation starting-game position in the MVP lineup.

### P1 — Starting pitcher could disagree with the lineup's P position — RESOLVED

**Attack:** select player A as P, then choose player B from the starting-pitcher picker.

**Before:** pitcher identity and defensive position could diverge.

**Fix:** selecting the starting pitcher assigns that player to P and clears P from another player. Assigning P through the position menu likewise updates starting pitcher. Validation rejects disagreement.

### P2 — Default roster positions can create duplicate lineup positions — ACCEPTED UX BEHAVIOR

**Attack:** add several players whose default position is SS.

**Result:** lineup can temporarily contain duplicate positions while being edited, but Start Game stays disabled until all nine positions are valid. This is deliberate because silently rewriting defaults would be surprising.

**Follow-up:** Slice 2 UI should eventually highlight missing/duplicate positions more explicitly if field testing shows confusion. Logged as polish, not a blocker.

## Static validation

All Swift sources were parsed with Swift 6.2.1 on Linux using `swiftc -frontend -parse`. Syntax parsing passed.

Full SwiftUI/SwiftData compilation and iOS simulator tests remain impossible in this Linux environment and are required on macOS before merge.

## Merge recommendation

**Conditional approval.** No unresolved P0/P1 adversarial findings in the source review. Do not merge until the macOS Xcode build/tests are green per `CURRENT_STATE.md`.
