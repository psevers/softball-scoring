# Slice 4 Changeset

Suggested commit after macOS/Xcode validation:

```text
feat: add ball-in-play runner scoring
```

## New files

- `ScoringEngine/BallInPlayValidator.swift`
- `Features/Games/RunnerConfirmationSheet.swift`
- `docs/reviews/SLICE4_ADVERSARIAL_REVIEW.md`
- `docs/SLICE4_CHANGESET.md`

## Modified implementation

- `Domain/GameEvent.swift`
- `ScoringEngine/GameState.swift`
- `ScoringEngine/GameReducer.swift`
- `ScoringEngine/GameEventReplay.swift`
- `Persistence/GameEventRecorder.swift`
- `Features/Games/LiveGameView.swift`
- `Tests/ScoringEngineTests/GameStateTests.swift`

## Modified project documentation

- `README.md`
- `docs/ARCHITECTURE.md`
- `docs/BACKLOG.md`
- `docs/CURRENT_STATE.md`
- `docs/SCORING_RULES.md`
- `docs/TEST_MATRIX.md`

## Validation in build environment

- Swift 6.2.1 parser: PASS across all Swift source/test files.
- Pure Swift Ball In Play event codec round trip: PASS.
- Pure Swift reducer/validator harness: PASS.
- Adversarial source review: no unresolved P0/P1 findings.

## External merge gate

macOS/Xcode + iOS simulator tests and CI are still mandatory because SwiftUI/SwiftData cannot be typechecked on this Linux environment.
