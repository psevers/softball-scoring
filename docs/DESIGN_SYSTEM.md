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

### Live scoring and runner confirmation

Live offense, live defense, and runner confirmation are contiguous ledger surfaces optimized for rapid scoring:

- Live scoring begins with one compact 180–200pt at-bat cell containing inning/half, score, game format or timer, current batter or pitcher, count, outs, and base state. Pitch and scoring actions immediately follow the cell.
- The standard-size score and count remain monospaced; team/player identity and concise result notation are expressive. Accessibility sizes use a concise textual game summary and system headline/body roles instead of enlarging decorative marks.
- The full batting line uses `ScorebookStatGrid` so all supported categories stay aligned and reflow rather than truncate at accessibility sizes.
- The full batting line follows the primary scoring controls; it never delays pitch or result entry.
- Live actions use `ScorebookKeyButtonStyle` at the 52pt game-action minimum. Safe/advancing outcomes may use muted green; caught stealing, validation failure, and history protection use explicit destructive red alongside textual meaning.
- Base and out marks use lightly offset graphite strokes for pencil character. Occupied bases retain a runner number and accessibility description; out state includes a numeric text label.
- Runner confirmation starts with the outcome and a short destination instruction, then native destination menus, steppers, toggles, Cancel, and Record actions. Longer attribution guidance follows the controls in a native disclosure.

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
