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

Use system typography for reliability and legibility. The handmade feel comes from geometry, ruling, notation, and restrained imperfection—not from sacrificing readability with a novelty font.

### Game surfaces

Live scoring, box score, lineup, and play history should feel like contiguous pages of one scorebook. Prefer:

- ruled stat tables,
- sketched base diamonds,
- circled/filled out markers,
- pencil-like notation,
- small annotation-style metadata,
- off-white sheets.

### Administrative surfaces

Roster/season editors may remain closer to native Forms. Apply the paper background and rule language but do not make basic data entry slower.

Game setup and lineup are scorebook pages rather than generic administration. They use ruled paper, a faint scorebook margin, graphite marks, serif page headings, and pencil-rule dividers while retaining native fields, pickers, and buttons.

### Interaction invariants

- 44pt minimum target.
- 52pt+ preferred live-game actions.
- Never require a hand-drawn gesture for correctness.
- Visual texture cannot reduce outdoor contrast.
- Destructive/correction state remains unambiguous despite the monochrome aesthetic.

### Core components

- `ScorebookPaperBackground`
- `ScorebookSheet`
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
