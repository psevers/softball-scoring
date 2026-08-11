# Design System

## Direction: a real scorebook on your phone

The visual language is pencil-on-scorebook-paper, but the interaction model stays native and fast.

### Materials

- Warm off-white `paper` base rather than stark white.
- Fine low-contrast square ruling on live game surfaces.
- Graphite/ink as the primary visual mark.
- Native accent color only for selected state, continuation, and confirmations.
- Hairline rules rather than card-heavy shadows.

### Typography

Use a role-based pairing rather than one typeface everywhere:

- Patrick Hand for expressive scorebook roles: page titles, team/player names, play notation, short annotations, and compact action labels.
- Semantic SF Pro text styles for forms, alerts, longer instructions, editable content, and accessibility-critical text.
- Monospaced system digits for statistics, scores, counts, timers, and aligned tables.

Custom typography must scale from semantic Dynamic Type styles. Do not use handwriting below body size for dense copy, and fall back to system typography wherever truncation or rapid numerical comparison would suffer. See `docs/adr/0001-selective-handwritten-typography.md`.

Patrick Hand Regular is bundled at `Resources/Fonts/PatrickHand-Regular.ttf`; its SIL Open Font License is retained beside it at `Resources/Fonts/OFL.txt`.

### Game surfaces

Live scoring, box score, lineup, and play history should feel like contiguous pages of one scorebook. Prefer:

- ruled stat tables,
- sketched base diamonds,
- circled/filled out markers,
- pencil-like notation,
- small annotation-style metadata,
- off-white sheets.

Avoid stacks of floating rounded cards. Use contiguous ledger sections, shared hairline boundaries, compact row metrics, and square or nearly square geometry so the paper remains the surface rather than decoration behind a dashboard.

### Administrative surfaces

Roster/season editors may remain closer to native Forms. Apply the paper background and rule language but do not make basic data entry slower.

Game setup and lineup are scorebook pages rather than generic administration. They use contiguous ruled rows, a faint scorebook margin, graphite marks, handwritten headings and player names, and tabular numerals while retaining native fields, wheel pickers, menus, reorder/delete controls, and buttons. Sections meet at hairline rules with no floating-card gaps.

### Interaction invariants

- 44pt minimum target.
- 52pt+ preferred live-game actions.
- Never require a hand-drawn gesture for correctness.
- Visual texture cannot reduce outdoor contrast.
- Destructive/correction state remains unambiguous despite the monochrome aesthetic.

### Core components

- `ScorebookPaperBackground`
- `ScorebookLedger`
- `ScorebookPageSection`
- `ScorebookLedgerRow`
- `ScorebookLabel`
- `ScorebookStatGrid`
- `ScorebookKeyButtonStyle`
- `ScorebookEmptyLedger`
- `ScorebookSheet` (legacy card wrapper pending surface migration)
- scoreboard / line-score grid
- base diamond
- count indicator
- pitch result keys
- outcome keys
- runner movement row
- play log row
- stat row
- scorebook duration wheel with large minute readout

### Reference design

The approved concept direction is represented by the generated pencil-scorebook mockups from Window 1. Implement the language, not pixel-for-pixel generated text/content.
