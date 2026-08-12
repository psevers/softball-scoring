# Test Matrix

## Scorebook visual foundation

- The bundled Patrick Hand resource resolves by PostScript name in the hosted app runtime.
- Games home retains its empty and populated navigation behavior after moving from a native list to ledger sections.
- The app remains a coherent light-paper surface when the device uses Dark Mode.
- Expressive text scales from semantic Dynamic Type roles; dense metadata and numerical text retain system typography.

## Pitch/count regression

- 0/1/2 ball progression.
- Fourth ball completes BB.
- 0/1/2 strike progression.
- Third called/swinging strike completes K.
- Two-strike foul stays at two live strikes and increments pitch strike count.
- HBP total-only pitch classification.
- Ball In Play increments one pitch and enters pending-result state.
- Another pitch while pending is rejected/ignored.

## Base occupancy matrix for Ball In Play

Exercise outcome confirmation from all eight starting base states:

1. Empty
2. 1B
3. 2B
4. 3B
5. 1B + 2B
6. 1B + 3B
7. 2B + 3B
8. Loaded

Across representative:

- 1B
- 2B
- 3B
- HR
- E
- FC
- one-out batted outs
- Sac Fly / Sac Bunt
- Double Play

## Movement invariants

- Every occupied runner + batter appears exactly once.
- Missing runner rejected.
- Unexpected runner rejected.
- Duplicate source rejected.
- Second cannot finish at first.
- Third cannot finish at first/second.
- Two runners cannot finish at same base.
- Runner may hold current base.
- Batter may be out after credited hit while attempting extra base.

## Outs and inning boundary

- Play may record zero outs.
- One out adds one.
- DP adds exactly two.
- Play cannot create >3 inning outs.
- Third out clears bases/count and advances half.
- Sacrifice credit rejected when starting with two outs.

## Third-out runs

- Home touch + third out requires explicit counted-run quantity.
- Counted run quantity must be 0...home touches.
- RBI cannot exceed counted runs.
- Zero runs count on force-style third out.
- Timing play can count one of multiple apparent home touches.
- Third-out score applied before inning transition and survives replay.

## Persistence/replay

- Encode/decode Ball In Play payload round-trip.
- Relaunch while pending Ball In Play returns to outcome selection state.
- Relaunch after completed play restores score, bases, outs, batter and pitch totals.
- Malformed/duplicate sequence history is rejected and scoring pauses.

## Game setup

- Nine-player batting order with nine regulation defenders is accepted.
- 11–13-player batting orders with exactly nine defenders and batting-only entries are accepted.
- Duplicate players, missing/duplicate regulation positions, more than nine defenders, and a pitcher not assigned P are rejected.
- Full batting order and defensive assignments survive persistence.
- Innings-based and time-limited formats survive persistence.
- Time-limit setup offers 30–90 minutes in five-minute stops without opening a keyboard.
- Both time-limit endpoints and Set Lineup remain reachable by touch on a small iPhone.
- Timed status reaches expiration without silently finalizing the game.
- Deterministic previews render a populated time-limit Game Card and a fourteen-batter lineup without relying on current dates or unordered fetches.

## Roster and lineup reachability

- A finger swipe reaches and opens the inactive player after a 14-player active Team roster.
- A 14-player batting order can be built by touch, its final batter remains reachable, and Start Game saves and opens the live game.
- With accessibility-extra-large Dynamic Type encoded in the app launch, New Game scrolls to the time-limit wheel and Set Lineup action; the fourteen-batter lineup scrolls between its last batter, pitcher control, and summary before saving.

## Administrative scorebook alignment

- Deterministic preview data covers one team, fourteen active and one inactive player, active and historical seasons, and a final game with a complete fourteen-player lineup.
- Standard-size UI evidence covers Team/roster, a native player editor, Seasons, final game summary, and the intentional Stats empty ledger.
- At Accessibility XL, a lower long-roster row and its native editor remain reachable, Seasons remains usable, the final-game summary reflows without losing navigation, and the Stats empty state remains reachable.
- Native team, player, and season editor controls retain their existing text fields, pickers, toggles, validation, confirmation, and destructive behavior.

## Live scorebook visual alignment

- Deterministic fixtures replay into an offensive state with prior batting totals, a 1–1 count, and runners on second/third; a defensive state with one out, a 1–1 count, and a runner on first; and a rejected corrupt-history state that gates scoring.
- SwiftUI previews cover offense, defense, occupied bases, outs/count, the complete batting-total grid, history protection, both runner-confirmation sheets, and Accessibility XL reflow.
- At deterministic Accessibility XL, the quick-result workflow reaches Walk, Home Run, a confirmed 1B, Record, back navigation, and persisted batter progression.
- At deterministic Accessibility XL, the normal-pitch workflow reaches count entry, SB, CS, the earlier pitch section after runner scoring, strikeout completion, and the next batter.
- At standard size, the initial live viewport exposes the current batter, count, Ball, and Strike before opening runner confirmation.
- At Accessibility XL, destination and RBI controls remain in the initial runner-confirmation viewport and retain stable accessibility identifiers.
- Standard and Accessibility XL simulator inspection checks the compact at-bat hierarchy, readable identity/numerical roles, non-overlapping runner controls, and preserved native navigation/toolbars. The final post-review ticket #8 evidence was explicitly approved on August 11, 2026.

## Tracked-team offense

- Offensive event codec preserves historical player identity and explicit counted-run sources.
- Authoritative recorder resolves the current batter from persisted lineup/player records.
- Nine- and thirteen-player orders wrap using their actual length.
- Third out preserves the next tracked batter for the following offensive inning.
- Reload/replay restores the next batter and real-player base occupancy.
- Historical events replay after current lineup metadata/order changes because each event owns its batting-order context.
- A pitch sequence cannot be completed by a different player identity at the same lineup slot.
- Cold-store reload restores batter, live count, bases, score, and derived batting projection.
- Defensive pitch recording succeeds after an offensive half-inning.
- Rapid stale offensive writes are rejected before they can score the next batter.
- Normal Ball/Strike/Foul/Swing entry completes BB/K and preserves the two-strike foul rule without opponent-pitcher stats.
- BB/HBP force only required runners; a loaded award credits the runner from third and one RBI.
- HR moves and credits every occupied real-player runner.
- Offensive ball-in-play suggestions cover hits and double plays before scorer confirmation.
- Runner passing, base collisions, backward movement, excess outs, and ordinary batter-out timing runs are rejected.
- SB advances the identified runner; CS removes that runner and adds an out without advancing the batter.
- Steal of home credits one run and SB without RBI; third-out CS advances the half and clears remaining runners.
- SB/CS rejects an occupied destination, wrong runner identity, and the wrong half-inning.
- Batting projection covers every PA result and credits PA/AB/H/2B/3B/HR/BB/HBP/SO/R/RBI/SB/CS without storing mutable totals.
- UI workflow records quick results and a confirmed single, then reopens the game at the correct next batter.
