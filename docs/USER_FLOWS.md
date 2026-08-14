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

Replay finds invalid event → display warning → block new scoring → show an explicit problem entry in Play History → preserve history for correction/recovery.

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

## Edit a completed defensive play — Slice 6

```text
Live Game → Play History → expand completed Ball In Play → Edit Play
  ↓
review the counted In Play pitch and current result separately
  ↓
choose corrected hit / home run / error / fielder's choice / ordinary out / sacrifice
  ↓
confirm batter and every occupied runner destination, counted home touch, and RBI
  ↓
preview score / bases / outs / opponent batter / pitcher total / downstream history
  ↓
Cancel unchanged, or Save one atomic result replacement → refreshed History + live scoring
```
