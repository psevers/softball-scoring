# Scorebook Design Direction

`scorebook-direction.png` is the approved visual north star from Window 1.

Use it for material, density, hierarchy, and scorebook familiarity. Do not copy generated labels or invented controls literally. Product behavior remains governed by `PRODUCT.md`, `SCORING_RULES.md`, and the implemented domain model.

The key design tension is intentional:

- **looks like a familiar scorebook**,
- **behaves like fast software**.

The UI should feel as though a clean paper scorebook became interactive: warm paper, faint grid/rules, pencil-like notation, diamonds, compact stat tables. But every important action uses explicit tap targets, immediate feedback, undo, and accessible native controls.

Slice 5.5 makes this reference a measurable visual target across every current screen. Game surfaces receive the strongest ledger/notation treatment; administrative editors inherit the same typography, rules, headers, and materials while preserving native data-entry behavior. Do not fabricate inning lines, play history, or annotations before the underlying projections exist.
