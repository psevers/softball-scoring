# User Flows

## Team setup

Team → Roster → Add/Edit Player → Season → Set Active Season

## Start game

Games → New Game → Opponent / Date / Home-Away / Season → Set Lineup → Assign 9 defensive positions → Choose starting pitcher → Start Game

## Resume game

Games → In Progress → Resume → replay persisted events → Live Game

## Defensive pitch — Slice 3

```text
Live Game
  ↓
Opponent batting?
  ├─ No → show current offensive-half boundary state
  └─ Yes
       ↓
Tap Ball / Called Strike / Swing / Foul / HBP
       ↓
Persist one GameEventRecord
       ↓
Replay ordered history
       ↓
Render count / outs / bases / pitch total / score
```

Terminal transitions:

- Ball 4 → BB → forced advance → next batter.
- Strike 3 → K → out → next batter.
- HBP → awarded first → forced advance → next batter.
- Out 3 → clear bases/count/outs and advance half-inning.

## Corrupt history

Replay finds invalid event → display warning → block new scoring → keep Play History reachable → show an explicit problem entry.

Unknown kind or malformed payload → expand exact problem record → Delete Unreadable Event → confirm sequence/ID/kind and deletion-only intent → stage without persistence → full replay/projection preview → remaining invalid record keeps Save disabled, or atomic exact deletion → refresh History → resume scoring → relaunch same repaired state.

Invalid sequence or semantic rejection → preserve the record; only a separately supported explicit correction may change it. Never guess missing meaning or silently skip it.

## Play History — Slice 6

```text
Live Game → History
  ↓
fresh one-game authoritative fetch
  ↓
replay + batting projection + event trace
  ↓
group by half-inning and logical plate appearance
  ↓
expand component pitches/records → Back → unchanged Live Game
```

## Undo latest SB/CS — Slice 6

```text
Live Game or Play History → Undo Latest SB/CS
  ↓
confirm event-time runner + source + destination/out + result + sequence
  ↓
exact-timeline validation → replay/projection preview → atomic record removal
  ↓
restore runner/base/out/half-inning state → keep active batter and count unchanged
```

## Edit an earlier defensive count pitch — Slice 6

```text
Live Game → Play History → expand plate appearance → Edit Pitch
  ↓
review event-time inning/half + opponent slot + sequence + current result/count
  ↓
choose Ball / Called Strike / Swinging Strike / Foul
  ↓
full candidate replay/projection → first invalid later record disables Save
  ↓
Cancel unchanged, or Save one payload/kind → refreshed History + live scoring
```

## Edit an earlier tracked-team pitch — Slice 6

```text
Live Game → Play History → expand tracked plate appearance → Edit Pitch
  ↓
review event-time player + batting slot/order size + sequence + current result/count
  ↓
choose Ball / Called Strike / Swinging Strike / Foul
  ↓
rebuild from persisted batter context → replay/project every later offensive event
  ↓
Cancel unchanged, stage any rejected downstream repair, or atomically Save → relaunch same batter/count
```

## Edit an earlier tracked-team SB/CS — Slice 6

```text
Live Game → Play History → expand SB/CS entry → Edit Base Running
  ↓
review event-time runner/source, batting slot/order size, active batter/count, sequence, and batting line
  ↓
select an event-time eligible runner and SB or CS → preview legal destination/out
  ↓
full replay rebuilds bases, outs, score, half-inning, and R/SB/CS while preserving count/batter and zero RBI
  ↓
Cancel unchanged, explicitly repair any rejected downstream SB/CS, or atomically Save → relaunch same result
```

## Delete an earlier defensive pitch — Slice 6

```text
Live Game → Play History → expand plate appearance → Delete Pitch
  ↓
confirm exact inning/half + opponent slot + result + sequence
  ↓
stage removal → replay/project the complete candidate timeline from the beginning
  ↓
first invalid downstream record disables Save
  ↓
Cancel unchanged, or Save exact deletion → preserve sequence gap → refreshed History + live scoring
```

## Delete an earlier tracked-team pitch — Slice 6

```text
Live Game → Play History → expand tracked plate appearance → Delete Pitch
  ↓
confirm event-time player + batting slot/order size + result + sequence
  ↓
stage exact-record removal → replay/project every surviving offensive event
  ↓
first invalid downstream event disables Save and offers explicit repair
  ↓
Cancel unchanged, or atomically Save → preserve sequence gap → relaunch same corrected batter/count
```

## Edit a completed tracked-team play — Slice 6

```text
Live Game → Play History → expand tracked plate appearance → Edit Play
  ↓
choose corrected result and confirm the event-time batter plus every occupied runner destination
  ↓
if the play creates the third out with a home touch, classify force/batter-runner or timing
  ↓
confirm exact counted-run sources and RBI
  ↓
preview score before the transition, cleared count/bases/outs, next tracked batter, and batting lines
  ↓
Cancel unchanged, or atomically Save → relaunch same inning and player attribution
```

## Edit a completed defensive play — Slice 6

```text
Live Game → Play History → expand completed Ball In Play → Edit Play
  ↓
review the counted In Play pitch and current result separately
  ↓
choose corrected hit / home run / error / fielder's choice / ordinary out / sacrifice / double play
  ↓
confirm batter and every occupied runner destination, including each explicit out source
  ↓
if the play creates the third out with a home touch, classify force/batter-runner or timing
  ↓
confirm legally counted runs and RBI
  ↓
preview score before the inning transition, then cleared count/bases/outs and next batter state
  ↓
Cancel unchanged, or Save one atomic result replacement → refreshed History + live scoring
```

## Delete a completed defensive logical play — Slice 6

```text
Live Game → Play History → expand completed Ball In Play → Delete Completed Play
  ↓
confirm exact paired In Play pitch + result summaries and sequences
  ↓
stage both removals → replay/project from the state before the pitch
  ↓
first invalid downstream record disables Save and opens staged repair
  ↓
Cancel unchanged, or Save one atomic pair deletion → preserve survivor envelopes and gaps
```
