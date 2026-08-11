# Decisions

## ADR-001 — Native iOS instead of PWA

Use SwiftUI + SwiftData. The product is iOS-only, local-first, and heavily optimized for game-day interaction, offline reliability, undo, and native ergonomics.

## ADR-002 — iOS 18 minimum

Target iOS 18+ to keep the codebase modern and reduce compatibility surface for a personal app.

## ADR-003 — Event-derived scoring state

Game events will become the authoritative scoring history. Score, bases, count, pitch counts, box scores, and season stats are derived projections. This enables deterministic correction and undo.

## ADR-004 — Pitch counts are MVP/P0

Pitch-by-pitch tracking is core. The system must also support quick scoring and later pitch-count reconciliation so a missed pitch never blocks the scorer.

## ADR-005 — XcodeGen project definition

Use `project.yml` to make Xcode project structure reproducible across agent/context windows and minimize opaque project-file edits.

## ADR-006 — Players are deactivated, not deleted

Roster removal is modeled as `isActive = false`. Historical game integrity matters more than destructive roster cleanup, and inactive players can be restored with one action.

## ADR-007 — One active season

Exactly one season should be considered the default for new-game setup when seasons exist. Slice 1 centralizes the mutation in `SeasonSelection.activate`; Slice 2 consumes that value when creating games.

## ADR-008 — Native administration UI before custom scoring UI

Roster, team, and season management use standard SwiftUI List/Form/Picker/sheet patterns. Custom visual design effort is intentionally deferred to the live scoring flow where interaction speed and outdoor readability justify it.

## ADR-005 — Pencil scorebook visual language, digital interaction model

**Decision:** Use warm paper, faint scorebook ruling/grid, graphite-like marks and hand-drawn diamond motifs on game surfaces. Preserve native SwiftUI controls, legible typography, and minimum touch targets.

**Why:** The visual metaphor should feel immediately familiar to a scorekeeper without recreating the limitations of a paper scorebook. The interaction remains outcome-first and software-native.

## ADR-006 — Adversarial review is a merge gate

**Decision:** Every PR requires a separate adversarial review before merge. P0/P1 findings block merge. Scoring-engine changes require hostile scenario tests.

**Why:** Small state errors can silently invalidate a box score or season aggregate. Correctness and recoverability are product features, not QA cleanup.
