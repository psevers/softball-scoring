# Ticket #10 evidence inventory

Baseline: repository commit `22b5c2ed30891332c42a1da5c564e9a16f1acf01` (the merge of PR #15), inspected 2026-08-12. This note uses only the ticket/spec, merged PRs, repository sources, and local Xcode/simulator artifacts.

## Acceptance contract

[Ticket #10](https://github.com/psevers/softball-scoring/issues/10) requires all of the following before Slice 5.5 is complete:

1. Repository-retained screenshots include Games home, New Game/lineup, live offense, live defense, runner confirmation, team/roster, season/editor, game summary, and supported Stats/empty state.
2. Evidence covers both a small and regular iPhone at both standard and accessibility Dynamic Type.
3. A dark **system** setting still produces the coherent light-paper app; dark-paper design is explicitly out of scope.
4. Critical game/player labels do not truncate, essential actions remain reachable, numerical columns remain aligned, and selected/destructive/invalid meaning is not conveyed by typography or color alone.
5. Representative implementation captures are shown beside the approved Window 1 reference and receive explicit product-owner approval.
6. The generated project and complete unit/UI scheme pass after final visual adjustments.
7. Standards and spec-compliance review passes, run against the Slice 5.5 starting point, have no unresolved P0/P1 findings.
8. Exact device, simulator/runtime, content-size, and dark-system configurations are recorded, and verification/current-state documentation is updated plainly.

The parent spec adds minimum 44-point targets, 52-point-or-larger live actions, an outdoor-like bright-display contrast inspection, and preservation of native workflows and accessibility semantics. It explicitly rejects pixel-perfect snapshot approval as a CI gate. [Spec decisions and test requirements][spec]

One ambiguity remains: neither ticket #10 nor parent #5 names the review-base SHA. History shows `cda3da4` is the direct parent of `a586658` (`feat: establish scorebook visual foundation`), so `cda3da4` is the likely Slice 5.5 starting point, but the final review should record that choice explicitly rather than silently assume it.

## Required evidence matrix

The safest literal reading is the nine ticket-listed surface groups across a 2 × 2 device/type grid. Grouped labels need enough frames to show both members (for example, New Game **and** lineup). Dark-system proof is an additional representative configuration, not a required 2 × 2 × 2 cross-product: the ticket says to “include evidence” under dark system, while the spec requires light-paper under dark system and excludes a dark-paper theme. [Ticket #10](https://github.com/psevers/softball-scoring/issues/10) [Parent testing decisions][spec]

| Axis | Required/selected values | Primary-source basis |
| --- | --- | --- |
| Surfaces | Games home; New Game; lineup; live offense; live defense; both supported runner-confirmation variants; Team/roster and native editor; Seasons and editor; final game summary; Stats empty state | Ticket #10 and the deterministic surface list in the [parent spec][spec] |
| Device | Small iPhone: **iPhone 17e**; regular iPhone: **iPhone 17** | Ticket says small + regular. The baseline docs already call 17e the smallest installed test phone and use 17 as the regular validation device. [Current state][current-state] |
| Dynamic Type | Standard/default; **Accessibility XL** (`UICTContentSizeCategoryAccessibilityXL`) | Current UI harness uses the exact launch argument for its accessibility branch. [UI launch helper][ui-tests] |
| System appearance | Light for the main matrix; Dark for explicit light-paper proof | The app intentionally forces `.preferredColorScheme(.light)`. [Root tab source][root-tab] |
| Orientation/platform | Portrait, full-screen iPhone; deployment target iOS 18+ | [Generated-project specification][project] |

Bold Text and Increased Contrast are accessibility user stories, but neither ticket #10 nor the parent testing decisions makes them additional screenshot-matrix axes. They remain sensible manual semantic spot checks, not substitutes for the required 2 × 2 evidence.

## Deterministic fixtures and capture seams

| Reusable seam | What it deterministically provides | Current limitation for ticket #10 |
| --- | --- | --- |
| `PreviewData` | Fixed dates, stable player data, populated/empty Games, fourteen-player lineup, active/historical seasons, final summary, live offense with totals/runners, live defense with runner/out, corrupt-history state, and offensive/defensive runner states. [Fixture source][preview-data] | Preview availability is not repository-retained screenshot evidence. |
| `DesignSystemTests` | Executes offense/defense/corrupt preview histories and asserts the administrative fixture shape. [Fixture tests][design-tests] | Verifies fixture meaning, not layout, device size, truncation, or reachability. |
| `UITestData.makeContainer()` | In-memory team, 14 active + 1 inactive players, a live game, and a 14-player final summary, selected by the app's `-uiTesting` launch argument. [UI seed][ui-seed] | It does not currently seed a defensive live game or every editor state. |
| Named XCUITest attachments | Standard + Accessibility XL live offense/runner captures and standard + Accessibility XL Team/editor/Season/summary/Stats captures, with `.keepAlways` attachment names. [Current capture tests][ui-tests] [Attachment helper][capture-helper] | Baseline tests capture only iPhone 17 runs, do not capture Games home/New Game/lineup/live defense/defensive runner confirmation, and have no theme metadata or dark-system branch. |
| Existing reachability workflows | Time wheel, 14-player lineup, inactive roster, quick offense, normal pitches, SB/CS, persistence/reopen, and Accessibility XL controls. [UI workflows][ui-workflows] | Several workflows assert behavior without taking a named screenshot at the acceptance point. |
| CI workflow | Generates the project, creates/boots a fresh latest-runtime iPhone 17 simulator, builds once, then runs domain/scoring and UI phases. [CI workflow][ci] | CI has one regular device and default content/theme only; it is a regression gate, not the evidence matrix. |

The reusable capture path is therefore: run the named UI workflows on an explicitly selected simulator with a result bundle, export `.keepAlways` attachments with `xcresulttool`, rename them from the manifest's human-readable attachment names, and retain the PNGs plus configuration manifest in the repository. The current test source makes the seed, Accessibility XL argument, assertions, and attachment names deterministic; ticket #10 still needs to add the missing capture entry points/configuration recording.

## Already available evidence

### Retained in the repository

- The sole tracked raster evidence/reference asset at the baseline is [`docs/design/scorebook-direction.png`](../design/scorebook-direction.png), a 1536 × 1024 PNG with SHA-256 `09b5c82a3be76f549c66186c3262591267fb5f9d78ba549c7267134759e1fec9`. The repository identifies it as the approved Window 1 visual north star for material, density, hierarchy, and scorebook familiarity—not literal product behavior. [Reference description][reference]
- Deterministic fixture/test source and the documentation claims from tickets #6–#9 are retained. The baseline tree contains no tracked implementation screenshots, evidence manifest, result bundle, or side-by-side comparison (`git ls-files` finds only the reference PNG among raster/evidence artifacts).

### Locally available, but not repository-retained

- `/private/tmp/ticket8-approval-evidence-20260811-1909.xcresult` reports two passing UI tests on iPhone 17 / iOS 26.5. Its exported manifest contains four named captures: standard live offense, standard runner confirmation, Accessibility XL live offense, and Accessibility XL runner confirmation. [PR #13](https://github.com/psevers/softball-scoring/pull/13) records the corresponding full-scheme result and prior visual approval.
- `/private/tmp/ticket9-final-evidence.0XTX2h/manifest.json` maps 14 iPhone 17 captures: five standard and five Accessibility XL administrative frames (Team, Player editor, Seasons, summary, Stats), plus the four ticket #8 live/runner frames. [PR #15](https://github.com/psevers/softball-scoring/pull/15) records the administrative validation.
- Loose regular-iPhone captures exist for the foundation and setup: `/private/tmp/slice5_5_ticket6-games-home.png`, `/private/tmp/slice5_5_ticket6-games-home-a11y-fixed.png`, `/private/tmp/slice5_5_ticket6-games-home-dark-system.png`, `/private/tmp/slice5_5-ticket7-new-game-standard-approved-candidate.png`, and `/private/tmp/slice5_5-ticket7-new-game-accessibility-approved-candidate.png`. [PR #11](https://github.com/psevers/softball-scoring/pull/11) and [PR #12](https://github.com/psevers/softball-scoring/pull/12) describe the prior inspections.
- The latest local full-scheme bundle, `~/Library/Developer/Xcode/DerivedData/SoftballScoring-elcyuxupqzwjuoemtyliyxjrsjbl/Logs/Test/Test-SoftballScoring-2026.08.11_23-47-30--0500.xcresult`, reports 112 tests / 115 parameterized cases passing with zero failures/skips on iPhone 17 / iOS 26.5. The same result is recorded in [current state][current-state].

These are valuable recapture inputs and regression evidence, but temporary paths and DerivedData are neither reproducible repository retention nor reviewable from GitHub.

## Gaps to close

1. **Repository evidence set:** no baseline implementation capture or manifest is tracked.
2. **Small device:** no inventoried capture manifest names an iPhone 17e; all mapped ticket #8/#9 attachments name iPhone 17.
3. **Surface completeness:** no retained capture covers live defense or the defensive runner-confirmation variant; loose setup evidence covers New Game but not a complete lineup frame; the baseline UI attachment tests do not capture Games home, setup, lineup, or the actual Season/Team editor variants comprehensively.
4. **Matrix completeness:** existing regular-iPhone captures are partial at standard/Accessibility XL; no complete nine-group 17e × 17 / standard × Accessibility XL set exists.
5. **Theme proof:** a loose Games-home dark-system PNG exists, and the source forces light appearance, but no tracked manifest records the dark-system configuration or proves representative native-form/sheet coherence.
6. **Semantic visual checks:** reachability assertions exist, but the repository lacks a review checklist/result covering truncation, aligned numerical columns, selected/destructive/invalid non-color signals, bright-display contrast, and exact configuration metadata across the final matrix.
7. **Reference comparison:** the approved reference is retained, but no committed representative side-by-side/contact sheet exists.
8. **Approval:** ticket #8 has documented product-owner approval and earlier PRs record scoped inspection, but ticket #10 has no comment and no explicit approval of the complete cross-surface evidence set.
9. **Final gates:** rerun the full scheme after final ticket #10 adjustments; run both review passes against an explicitly recorded base; update `docs/CURRENT_STATE.md` (whose baseline still describes ticket #9 as local/pending publication later in the file) and record final verification.

## Runtime and simulator availability at inventory time

- Xcode 26.6 (`17F113`) selected at `/Applications/Xcode.app/Contents/Developer`; XcodeGen 2.46.0.
- Installed available runtime: iOS 26.5 (`23F77`).
- Existing available devices on that runtime include iPhone 17e (`8D51D517-AA1B-40EF-9519-AED1F963EA4E`, shutdown) and iPhone 17 (`FB739517-7F6A-4309-A112-B50143709CA5`, booted at inspection), so the proposed small/regular pair is immediately available.
- GitHub CI selects Xcode 26.3, chooses the newest available iOS runtime, and creates a fresh iPhone 17 simulator to avoid the hosted pre-created-device boot stall documented in [PR #14](https://github.com/psevers/softball-scoring/pull/14). Local evidence should record its Xcode 26.6/iOS 26.5 difference rather than imply byte-identical CI infrastructure.

## Recommended capture order

First make one deterministic test/capture path cover every surface, then execute the four required device/type configurations, add a representative dark-system run, export/rename attachments and commit them with a machine-readable manifest, build the side-by-side reference comparison, collect product-owner approval, and only then run the final full scheme and two review passes. This order minimizes recapture if a fixture or semantic visual check exposes a focused fix.

[spec]: https://github.com/psevers/softball-scoring/blob/22b5c2ed30891332c42a1da5c564e9a16f1acf01/docs/specs/SLICE5_5_SCOREBOOK_VISUAL_ALIGNMENT.md#L38-L77
[current-state]: https://github.com/psevers/softball-scoring/blob/22b5c2ed30891332c42a1da5c564e9a16f1acf01/docs/CURRENT_STATE.md#L81-L116
[reference]: https://github.com/psevers/softball-scoring/blob/22b5c2ed30891332c42a1da5c564e9a16f1acf01/docs/design/README.md#L1-L14
[preview-data]: https://github.com/psevers/softball-scoring/blob/22b5c2ed30891332c42a1da5c564e9a16f1acf01/DesignSystem/PreviewData.swift#L5-L197
[design-tests]: https://github.com/psevers/softball-scoring/blob/22b5c2ed30891332c42a1da5c564e9a16f1acf01/Tests/DomainTests/DesignSystemTests.swift#L6-L77
[ui-seed]: https://github.com/psevers/softball-scoring/blob/22b5c2ed30891332c42a1da5c564e9a16f1acf01/Persistence/UITestData.swift#L5-L75
[ui-tests]: https://github.com/psevers/softball-scoring/blob/22b5c2ed30891332c42a1da5c564e9a16f1acf01/Tests/SoftballScoringUITests/ScrollReachabilityUITests.swift#L5-L137
[ui-workflows]: https://github.com/psevers/softball-scoring/blob/22b5c2ed30891332c42a1da5c564e9a16f1acf01/Tests/SoftballScoringUITests/ScrollReachabilityUITests.swift#L139-L320
[capture-helper]: https://github.com/psevers/softball-scoring/blob/22b5c2ed30891332c42a1da5c564e9a16f1acf01/Tests/SoftballScoringUITests/ScrollReachabilityUITests.swift#L322-L408
[root-tab]: https://github.com/psevers/softball-scoring/blob/22b5c2ed30891332c42a1da5c564e9a16f1acf01/App/RootTabView.swift#L3-L32
[project]: https://github.com/psevers/softball-scoring/blob/22b5c2ed30891332c42a1da5c564e9a16f1acf01/project.yml#L1-L46
[ci]: https://github.com/psevers/softball-scoring/blob/22b5c2ed30891332c42a1da5c564e9a16f1acf01/.github/workflows/ios.yml#L8-L109
