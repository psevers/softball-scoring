# Slice 5.5 — Scorebook Visual Alignment

## Problem Statement

The app uses a warm paper background and graphite palette, but its typography, rounded cards, native lists/forms, separators, and control styling still read as generic SwiftUI placed over graph paper. It does not yet resemble the approved pencil scorebook reference or the way a scorekeeper writes and scans a real book. Building history and correction UI on the current visual foundation would spread the wrong hierarchy and create avoidable rework.

## Solution

Align every current screen with the approved scorebook direction while preserving native iOS interaction, accessibility, and all existing scoring behavior. Game surfaces become contiguous ruled ledger pages with compact notation and restrained pencil character. Administrative surfaces inherit the same typography, rules, headers, and materials at a lighter intensity. Patrick Hand supplies expressive scorebook roles; semantic SF Pro and monospaced system digits remain responsible for dense, editable, numerical, and accessibility-critical content.

## User Stories

1. As a scorekeeper, I want the live game to resemble a real scorebook page, so that its hierarchy feels immediately familiar.
2. As a scorekeeper, I want player and team names to look handwritten, so that recorded game information feels like pencil notation rather than generic app chrome.
3. As a scorekeeper, I want scores, counts, timers, and statistics to remain precisely aligned, so that handwriting never slows numerical comparison.
4. As a scorekeeper, I want live-game sections to share ledger rules instead of floating as separate cards, so that I scan one continuous page.
5. As a scorekeeper, I want pitch and outcome controls to look like scorebook keys while remaining large buttons, so that the app feels authentic without becoming slower.
6. As a scorekeeper, I want base diamonds and out indicators to feel drawn with pencil, so that core game state carries the visual identity.
7. As a scorekeeper, I want the current batter and pitcher to stand out through scorebook hierarchy, so that I can find them immediately.
8. As a scorekeeper, I want batting totals to read as a compact stat line, so that the page has the density of a scorebook without losing clarity.
9. As a scorekeeper, I want game setup and lineup construction to feel like filling out the first page of a book, so that the experience is visually continuous before first pitch.
10. As a scorekeeper, I want roster and season screens to share the same paper, typography, and rules, so that navigation does not feel like switching to a different product.
11. As a scorekeeper, I want administrative fields to retain ordinary iOS editing behavior, so that visual character does not make data entry awkward.
12. As a scorekeeper, I want selected and saved states to use a restrained green, so that confirmation is visible without overwhelming the graphite page.
13. As a scorekeeper, I want invalid and destructive states to remain unmistakably red, so that the monochrome aesthetic never obscures risk.
14. As a scorekeeper outdoors, I want rules and handwriting to retain sufficient contrast, so that paper texture does not disappear in glare.
15. As a user with larger text enabled, I want the scorebook hierarchy to scale without clipping controls or hiding actions, so that the visual system remains accessible.
16. As a user with Bold Text or increased contrast, I want critical content to remain legible, so that the handwritten font is never the only signal.
17. As a user in Dark Mode, I want a coherent light-paper scorebook instead of an accidental mixture of dark native rows and light paper, so that the visual metaphor remains intact.
18. As a maintainer, I want semantic typography roles, so that expressive and numerical text are selected consistently instead of through ad hoc font modifiers.
19. As a maintainer, I want reusable ledger sections, stat grids, labels, and key-button styles, so that all screens share one visual language.
20. As a maintainer, I want the custom font license retained with the app, so that font redistribution remains compliant.
21. As a reviewer, I want deterministic screenshots beside the approved reference, so that visual completion is judged with evidence rather than prose.
22. As a reviewer, I want existing behavioral tests to remain unchanged wherever possible, so that a styling pass cannot silently alter scoring workflows.
23. As a product owner, I want to approve the final screenshots before completion, so that the implementation matches the intended scorebook character.
24. As a future Slice 6 implementer, I want the visual system ready for real play history and annotations, so that correction UI can extend the established language without redesigning it.

## Implementation Decisions

- The approved Window 1 scorebook concept is the measurable visual north star for material, density, hierarchy, notation, and familiarity; it is not a literal source of product behavior or invented data.
- Bundle Patrick Hand Regular under the SIL Open Font License for page titles, team/player names, play notation, short annotations, and compact action labels. Retain the license notice with distributed resources.
- Use semantic SF Pro styles for forms, alerts, longer instructions, editable content, and accessibility-critical text.
- Use monospaced system digits for scores, statistics, counts, timers, jersey numbers in dense rows, and aligned tables.
- Scale the custom font from semantic Dynamic Type roles. Do not use handwritten microcopy below body size or where truncation makes rapid reading unreliable.
- Introduce semantic design-system roles for typography, ledger rules, row metrics, selection/destructive colors, page sections, compact stat grids, scorebook labels, and action keys.
- Game surfaces use the strongest treatment: contiguous ledger sections, shared hairline boundaries, square or nearly square geometry, compact rows, scorebook notation, and restrained pencil irregularity.
- Administrative surfaces use a lighter treatment while preserving native text entry, pickers, navigation, sheets, focus, and validation behavior.
- Preserve the native tab structure, navigation stacks, sheets, accessibility semantics, minimum 44-point targets, and 52-point-or-larger live actions.
- Keep graphite as the primary mark, muted green for selected/saved/positive state, and red only for destructive or invalid state.
- Apply a coherent light-paper appearance across every current screen for this slice. A dark scorebook system requires a separate design decision.
- Do not add placeholder inning lines, play history, notes, or notation unsupported by current projections.
- Do not change the event model, scoring rules, persistence semantics, or existing user workflows.
- Preserve behavior-oriented accessibility identifiers so current UI automation remains valid.
- The selective handwritten typography decision is recorded as a durable ADR because it supersedes the previous system-font-only policy.

## Testing Decisions

- Test external behavior at the highest existing seam: the current XCUITest workflows for game setup, long lineups, roster reachability, offensive quick results, normal pitch entry, base running, save, and reopen.
- Existing domain and scoring-engine suites must remain green even though the feature should not change their behavior.
- Add a font-registration smoke assertion or deterministic preview check that proves the bundled expressive typeface is available and the system fallback remains safe.
- Add deterministic visual fixture states for the most important surfaces: games home, game setup/lineup, live offense, live defense, runner confirmation, team/roster, season/editor, game summary, and stats/empty state as currently supported.
- Capture and commit screenshots for a small and regular iPhone at standard and accessibility Dynamic Type.
- Compare screenshots side by side with the approved reference during human review. Do not make brittle pixel-perfect screenshot comparison a required CI gate.
- Verify that every essential action remains reachable at accessibility sizes, labels do not truncate critical player/game state, numerical columns remain aligned, and selected/destructive state does not rely on font alone.
- Verify the light-paper appearance under a dark system setting and inspect contrast under an outdoor-like bright display.
- Slice completion requires explicit product-owner visual approval of the screenshot evidence.
- The full generated Xcode project and complete test scheme must pass before code review.

## Out of Scope

- Dark-paper or dark-scorebook appearance.
- New scoring data, inning-by-inning run projections, play history, notes, corrections, undo, or edit behavior.
- Changes to navigation architecture, tabs, sheets, scoring flow, event schemas, reducers, or persistence.
- Literal reproduction of generated mockup controls or labels that do not correspond to implemented behavior.
- Detailed fielding notation, spray charts, pitch location, or other deferred product features.
- Broad replacement of native text-entry controls with custom-drawn controls.
- Automated pixel-perfect snapshot approval in CI.

## Further Notes

The paper background is already liked and should be preserved and refined rather than replaced with photographic texture. The target character is neat printed scorebook stationery filled in with controlled pencil writing—not a noisy, rotated, or artificially messy sketch UI. The implementation must look familiar like a scorebook and behave quickly like software.
