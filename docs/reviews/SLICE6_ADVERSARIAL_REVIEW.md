# Slice 6 Adversarial Review

Status: **Local source, persistence, complete simulator scheme, and two-axis review passed; GitHub CI, manual exhaustive lane, and collaborator review remain required before merge.**

Scope: Play History, Undo, defensive and tracked-team correction/deletion, downstream repair, pitch reconciliation, locked-history recovery, and cold-relaunch durability from Slice 6 base `9937c6d` through ticket #25.

## Findings resolved

### P1 — cold-relaunch proof did not compare the complete durable result

The first deterministic recovery journey checked representative history rows and headline game state after process termination, but did not prove that every modified game's component-level timeline or the batting projection survived unchanged. The journey now captures every unique `Event <sequence>. <summary>` accessibility record for all five modified games before termination and compares the exact sets after relaunch. It also verifies the persisted PA/AB/H and SB/CS projection summaries.

### P1 — projection verification could dismiss the wrong sheet

The added projection assertions initially navigated back through a generic navigation-bar button, which could leave the edit sheet presented and make the subsequent history interaction ambiguous. The journey now dismisses the tracked-play and tracked-baserunning editors through their explicit Cancel controls.

### P1 — post-capture history lookup only searched downward

Component capture finishes at the bottom of a history timeline. The first tracked-play lookup used a downward-only scroll helper and therefore could not reach entry 1. The lookup now resets to the top before searching. The focused cold-relaunch journey passes with the complete timeline and projection assertions.

## Standards and maintainability review

No hard documented-standard violation or P0–P2 maintainability finding remains.

Two P3 refactor seams are accepted for follow-up rather than expanded into this recovery ticket:

- `GameEventCorrectionSession` stores staged work in eight parallel mutation arrays and duplicates preview-versus-durable mutation interpretation. A future refactor should use one typed staged-mutation collection interpreted by preview and save, reducing preview/save drift risk.
- `DefensivePitchEditView.swift` is a 2,310-line multi-workflow correction UI containing twelve screens plus shared repair orchestration. A future refactor should split it by workflow family around its existing coordinator and section seams.

These notes are also retained in the local backlog. Creating public GitHub follow-up issues requires explicit publication authorization and remains a pre-merge action.

## Verification

- `xcodegen generate`: PASS
- Workflow contract: 2 tests / 135 assertions PASS
- Focused deterministic recovery/cold-relaunch UI journey: PASS (431.181 seconds)
- Complete Xcode scheme on iPhone 17 / iOS 26.5: 296 tests PASS, 0 failures, 0 skips (2,233.025 seconds)
- Standard Dynamic Type and Accessibility XL light-paper screenshots: PASS visual inspection
- `git diff --check`: PASS
- Correctness/spec adversarial review: PASS, no unresolved P0/P1
- Standards/maintainability adversarial review: PASS, no hard violation or P0–P2 finding

## Merge decision

No unresolved P0/P1 local findings. Do not merge until the two accepted P3 follow-ups are published with authorization, GitHub fast and manual exhaustive verification are green, and the required collaborator review is complete.
