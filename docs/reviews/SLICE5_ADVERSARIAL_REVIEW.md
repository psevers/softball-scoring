# Slice 5 Adversarial Review

Status: **Local source, persistence, simulator, and two-axis review passed; GitHub CI and collaborator review remain required before merge.**

Scope: tracked-team offensive scoring, player attribution, normal and quick entry, batting projection, and SB/CS.

## Findings resolved

### P1 — strikeout third out could count a timing run

The offensive validator's ordinary batter-out guard omitted strikeout. A crafted two-out strikeout with a runner touching home could score. Strikeout now shares the no-run batter-out rule and hostile replay coverage rejects the history.

### P1 — defensive writes failed after offensive history

Historical replay depended on caller-supplied current lineup context. Replay is now self-contained; offensive events persist event-time batting identity and order size, while the mutable lineup only authorizes new writes.

### P1 — stale offensive taps could score the next batter

Every recorder entry point now compares the displayed batter or runner with authoritative stored replay before assigning the next sequence.

### P1 — a live count could change player identity at the same slot

Replay previously checked only lineup slot and size. `OffensiveCountContext` now binds the active count to the first pitch's full historical batter identity and rejects a mismatched pitch or completing PA. Terminal BB/K writes are validated before persistence.

### P1 — SB/CS boundaries lacked hostile coverage

Reducer, validator, projection, and persistence coverage now includes steal of home, third-out caught stealing, occupied destinations, wrong runner identity, wrong half-inning, and no-RBI steal scoring.

### P2 — cold reload and complete game-line evidence were partial

A fresh on-disk store reload now verifies batter, count, bases, score, and projection. The batter card displays all documented counting categories: PA, AB, R, H, 2B, 3B, HR, RBI, BB, HBP, SO, SB, and CS.

### P2 — projection decoding failure could appear as zero totals

The live screen now treats a projection decode failure as unreadable history and pauses scoring instead of silently presenting empty totals.

## Accepted maintainability note

`LiveGameView` carries several offensive UI and persistence responsibilities. This is non-blocking for the validated slice because behavior is protected at recorder/replay boundaries; extraction is recorded in `docs/CURRENT_STATE.md` as Slice 6 cleanup alongside history/undo work.

## Verification

- `xcodegen generate`: PASS
- Domain: 47 tests PASS
- Scoring engine: 53 tests PASS
- UI workflows: 5 tests PASS
- Full Xcode scheme: PASS
- Seeded iPhone 17 / iOS 26.5 simulator launch and visual smoke: PASS
- `git diff --check`: PASS

## Merge decision

No unresolved P0/P1 local findings. Do not merge until GitHub CI and required collaborator review are green.
