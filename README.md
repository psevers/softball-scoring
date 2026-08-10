# Softball Scoring

Local-first iOS fastpitch softball scorekeeping app for one team.

## Current milestone

Implementation and macOS/Xcode validation are complete through **Vertical Slice 4: Ball In Play + explicit runner scoring**.

## Stack

- Swift 6
- SwiftUI
- SwiftData
- iOS 18+
- XcodeGen for reproducible project generation
- Swift Testing

## Open locally

1. Install XcodeGen if needed: `brew install xcodegen`
2. Run `xcodegen generate`
3. Open `SoftballScoring.xcodeproj`
4. Select an iPhone simulator and run
5. Run the `SoftballScoring` scheme tests

## Current user flow

Open **Team** to configure the roster and season, create an innings-based or time-limited game under **Games**, build a variable batting order with nine defenders, then use the live scorebook to record defensive pitches and explicit ball-in-play runner outcomes.

## Next slice

Slice 5: tracked-team offensive scoring and player attribution. See [`docs/CURRENT_STATE.md`](docs/CURRENT_STATE.md).

## Development policy

Every PR requires an adversarial code review before merge. Reviewers are expected to actively construct failure cases, not just read the diff. P0/P1 findings block merge; scoring-engine changes require hostile regression scenarios. See `docs/CODE_REVIEW.md`.

The approved visual direction is a pencil-and-paper scorebook translated into fast native iOS interactions. See `docs/DESIGN_SYSTEM.md` and `docs/design/scorebook-direction.png`.
