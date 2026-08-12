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
