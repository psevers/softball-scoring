# Slice 3 Adversarial Review

Scope: persisted pitch events, deterministic replay/reducer, defensive live scoring UI, count rules, pitch totals, forced BB/HBP advancement, half-inning transition.

Reviewer stance: assume one malformed or duplicated pitch can poison the rest of the game and season stats.

## Findings

### P1 — Duplicate sequence numbers created ambiguous replay order — RESOLVED

**Attack:** persist two events with the same sequence number.

**Risk:** timestamp fallback made replay deterministic in practice but allowed an invalid event stream to exist. Editing/replay later could depend on accidental ordering.

**Fix:** `GameEventReplay` now requires every sequence number to be positive and unique. Duplicate/invalid sequence records are rejected and new scoring is paused.

### P1 — Pitch payload could be attributed to the wrong pitcher — RESOLVED

**Attack:** inject a valid pitch payload using a different pitcher UUID.

**Risk:** the game count could advance while the visible starting pitcher's total did not, creating stat divergence.

**Fix:** until pitcher-change events exist, replay requires every pitch event's pitcher ID to match the game's starting pitcher ID. A mismatch is rejected and scoring pauses.

### P1 — Semantically malformed batter slot could mutate downstream batting order — RESOLVED

**Attack:** inject a pitch event for opponent batter 7 while batter 1 is at the plate.

**Risk:** a terminal result could rotate the wrong logical plate appearance and corrupt all downstream attribution.

**Fix:** both reducer and replay validate that the payload batter slot equals `currentOpponentBatterSlot`.

### P1 — Defensive pitch event could be applied during our offensive half — RESOLVED

**Attack:** append a pitch after the third out has moved a home team's game from top to bottom.

**Risk:** pitch total/count could continue while the tracked team is batting.

**Fix:** replay semantically rejects defensive pitch events during a tracked-team offensive half; the reducer independently guards the same invariant.

### P1 — Unreadable persisted payload could be silently skipped — RESOLVED

**Attack:** change an event kind/payload to undecodable data.

**Risk:** silently skipping history makes the displayed state look trustworthy when it is incomplete.

**Fix:** replay surfaces rejected record IDs. Live scoring shows a corruption warning and blocks new pitch writes until history is repaired.

### P2 — Slice 3 cannot advance an away team's Top 1 offensive half — ACCEPTED SLICE BOUNDARY

**Attack:** create a game with our team Away.

**Result:** Top 1 correctly belongs to our offense, so defensive pitch buttons are unavailable. Slice 3 has no offensive event capable of reaching Bottom 1 yet.

**Disposition:** deliberate vertical-slice limitation, not a rules workaround. Slice 4/5 add ball-in-play and complete offensive scoring. Do not introduce a fake “skip half” event solely for prototype convenience.

### P2 — No pitch undo yet — ACCEPTED SLICE BOUNDARY

Mistaps are common on game day. Undo/edit is deliberately Slice 6 so the first event contract stabilizes append-only. The product is not MVP-ready until that slice lands.

## Behavior checks

Pure Swift reducer harness executed on Linux and passed:

- 4 balls → walk, first occupied by batter, count reset, pitch total 4.
- 2-strike foul → still 2 strikes, no out, foul counted as a strike pitch.
- 4 consecutive walks → bases-loaded forced run scored correctly.
- 3 strikeouts → half transitions Top→Bottom, outs/bases/count clear, next opponent batter preserved.

All project Swift files also pass Swift 6.2.1 parser validation with `swiftc -frontend -parse`.

## Required macOS gate

Full `SwiftUI`, `SwiftData`, macro expansion, XcodeGen generation, simulator rendering, and unit tests still require Xcode/macOS. This review is **conditional approval only** until CI/Xcode is green.

## Merge recommendation

**Conditional approval.** No unresolved P0/P1 findings in source/reducer review. P2 limitations are explicit later-slice scope and do not represent hidden correctness debt.
