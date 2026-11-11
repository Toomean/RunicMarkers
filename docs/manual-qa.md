# Runic Markers — Manual QA

In-game scenarios to catch regressions. Run them before every release and after notable changes.
The mod has no automated tests: results are only visible in the game.

## How to use

- **IDs never change.** An outdated scenario is marked `retired`, not deleted.
- **Last run**: date and result (`pass` / `fail` / `—` if never run). A scenario gets `pass` only when it was
  played in the game; a successful script compile is not a pass.
- On `fail`, write down what you saw (attach a screenshot when reporting).
- The **smoke** set (quick check, ~5 minutes) is marked ★.

## Setup

Steam launch options (Properties → General → Launch Options):

```
-as-development-mode -ingametools -ModsDirectory="<folder containing Reaper-RunicMarkers>" -Mods=Reaper-RunicMarkers
```

- `-as-development-mode`: shows script compile errors.
- `-ingametools`: debug panels (RunicMarkers menu).
- Load a save in an open area with walls, floor, an NPC and a chest nearby.

## A. Loading

| ID | Scenario | Steps | Expected | Last run |
|---|---|---|---|---|
| A1 ★ | Mod compiles and loads | Start the game with the options above | No compile error window; **RunicMarkers** in the top menu bar | 2026-11-01 pass |
| A2 | Settings in the game menu | Pause → Settings → Game → "[Mod] Runic Markers" section | Max distance and Rune glow are listed | 2026-11-01 pass |
| A3 | Game unchanged without the mod | Remove the launch options, load a save | The save loads, no trace of the mod | 2026-11-08 pass; the game shows "This save was made with a different modlist", Continue anyway loads it (screenshot `art/save-without-mode.png`), runes return when re-enabled |
| A4 ★ | Player-style loading (no development mode) | Launch options `-ModsDirectory="<folder>" -ModManagementUI` only; tick the mod in the Mod Management UI, start, load a save | Mod listed with the current version (0.2.0) and its description; no "Some mods couldn't be loaded"; settings, V/N/H and the key rows, rune list and save/load work | 2026-11-08 pass (`8bb8a7b`) |
| A5 | Settings page probe (0.2 discovery; RETIRED: probe removed in step 8) | In game: Esc → Settings → Game (as in A2), then Debug → RunicMarkers; also check the log | Debug 'Settings page probe' and the log (`[RunicMarkers][SettingsProbe]`) list the widget tree (host, root, widget count, one line per widget); `Probe runs: 0` = not attached | 2026-11-11 pass: probe ran (2 runs), GetAllWidgets and UWidget.GetParent compile; tree in Debug (art/05) |
| A6 | Key rows visible (0.2) | Esc → Settings → Game, scroll to the end of the list; Debug → RunicMarkers `Key rows` | Three rows "Place key" / "Next symbol key" / "Delete key" laid out like the game's rows (name left, key box right) showing the current keys (V / N / H by default), inside the Runic Markers section after 'Max marker distance' / 'Rune glow'; Debug `Key rows: rows added: 3, reused: 0, skipped: 0, game rows, game key box: 3; after the mod section (tick n) (keys: ...)`; opening the page again does not add more rows | 2026-11-11 pass (run 2): three game-style rows (name left, grey key box right) inside the mod section after Max marker distance / Rune glow; status `rows added: 3, reused: 0, skipped: 0, game rows; after the mod section (tick 3)`. Step 5 run: prototype rows above the section header (art/06) |
| A7 | Rebind place key works at once | Click the place key box, press **B**, close the menu, hold **B** | Box shows B; Debug `Key rows: place key set to B`; holding B shows the preview at once (no restart), V does nothing | 2026-11-11 pass: rebind to B works at once; step 7 (game key box): 2026-11-11 re-run pass |
| A8 | Duplicate key rejected | Click the place key box, press the current delete key (**H**) | Box shows the old place key again; Debug `Key rows: place key kept ... (H is already the delete key)` | 2026-11-11 pass: Next symbol key -> H rejected, reverted to N; step 7 (game key box): 2026-11-11 re-run pass |
| A9 | Esc cancels key selection | Click a key box, press **Esc** | Selection cancelled, the box shows the old key, the key is unchanged (Debug keys line); note whether the settings menu also closed; if it did, reopen Settings → Game and check the box still shows the old key | 2026-11-11 pass: Esc cancels the selection; the settings menu stays open; step 7 (game key box): 2026-11-11 re-run pass |
| A10 | Binding survives a restart | After A7: quit the game completely, start it, load a save | B still places; `GameUserSettings.ini` has the new key in a RunicMarkersKeyConfig section | 2026-11-11 pass |
| A11 | Key rows look native and sit in the mod section (0.2 step 6) | As A6; hover our rows with the mouse; close and reopen Settings, switch to another tab and back to Game; click a key box, move the mouse over another row, then press a key; Debug → RunicMarkers `Key rows` | Rows match the game's rows (name font / color, row height, hover highlight if the game shows one); step 6 only (superseded by A12): the key box itself still has the engine look (grey box, engine key text); the rows are the last entries of the "[Mod] Runic Markers" section; `Key rows` status has no FALLBACK and no WARNING; after reopening / switching tabs the rows are not duplicated, are still after the section and still read "Place key" / "Next symbol key" / "Delete key"; the rebind after moving the mouse over another row still works and the log has no "Accessed None" | 2026-11-11 pass (run 2): rows native and last in the mod section; reopen / tab switch: no duplicates, names kept; rebind after hovering another row OK, nothing in Debug (no log file under CrossOver); hover toggles Image_Hover_Left/Right (Hidden / SelfHitTestInvisible); game key selector listed (7 widgets, inner InputKeySelector). Run 1: fallback (row children empty before AddChild), fixed |
| A12 | Key box looks like the game's Key Bindings page (0.2 step 7) | As A6; compare with Settings → Key Bindings; then Debug → RunicMarkers `Key rows` | The key boxes of our three rows look like the game's key boxes (frame, font, icon if the game shows one) and show the current keys (e.g. B / N / H), not "None"; `Key rows` has `game key box: 3` and no `engine key box`; close and reopen Settings and switch tabs: the boxes still show the current keys, not "None"; then A7-A9 with these boxes | 2026-11-11 pass (art/09, art/10): the game's key boxes (dark box, light frame, game font) with V / N / H, matching Key Bindings; `game key box: 3`, no engine key box; row hover highlight works; Image_Icon SelfHitTestInvisible, no icon visible (only the key text); reopen / tab switch keeps the keys ("seems OK") |
| A13 | No probe, key rows unchanged (0.2 step 8) | Start, open Settings → Game, then Debug → RunicMarkers; rebind a key as in A7 | Debug has no 'Settings page probe' section; the `Key rows:` line is still shown (`rows added: 3, ..., game rows, game key box: 3; after the mod section ...`); the key rows look and work as in A6-A12 | 2026-11-11 pass (user: "everything works") |

## B. Placing

| ID | Scenario | Steps | Expected | Last run |
|---|---|---|---|---|
| B1 ★ | Rune on a wall | Stand ~1–2 m from a wall, aim, press **V** | Rune on the wall, aligned with the surface | 2026-11-01 pass |
| B2 ★ | Rune on the floor | Aim at the floor, press **V** | Rune on the floor | 2026-11-01 pass |
| B3 | One rune per press | Hold **V** for 2 seconds, release | Exactly one rune, placed on release | 2026-11-08 pass |
| B4 | Too far | Aim at a wall farther than Max distance (3 m), **V** | Nothing placed; Debug panel: `too far` | 2026-11-01 pass |
| B5 | Not on characters | Aim at an NPC, **V** | Nothing placed; `rejected: character` | 2026-11-01 pass |
| B6 | Not on movable objects | Aim at a movable object (door, item), **V** | Nothing placed; `rejected: non-static` | 2026-11-01 pass |
| B7 | Not through walls | Stand so the camera sees a surface around a corner that the hero does not, **V** | Nothing placed; `blocked` | 2026-11-01 pass |
| B8 | Distance setting | Settings → Game → Max marker distance = 500; repeat B4 | Now the rune is placed | 2026-11-08 pass |
| B9 | 100 rune cap | Place 101 runes | 100 runes; the oldest one disappeared | 2026-11-08 pass |
| B10 | No collision | Place a rune on the floor, walk over it | The hero does not stumble or get stuck | 2026-11-08 pass |
| B11 ★ | Preview | Hold **V** and move the camera | The selected rune follows the aim; it is hidden where placing is not allowed (too far, NPC, through a wall) | 2026-11-03 pass |
| B12 | Orientation on walls | Place the "Human" and the "Moon" on a wall | Upright, not mirrored | 2026-11-03 pass |
| B13 | Orientation on floors | Place the "Human" on the floor facing different directions | The head points away from the player | 2026-11-03 pass |

## C. Keys do nothing in menus

Keys are **V** (place), **N** (next symbol), **H** (delete) since 0.2 (0.1: T / Y / U; Last run entries before
2026-11-10 were played with T / Y / U).

| ID | Scenario | Steps | Expected | Last run |
|---|---|---|---|---|
| C1 ★ | Inventory | Open the inventory, press **V** | Nothing placed | 2026-11-01 pass |
| C2 | Dialogue | Talk to an NPC, press **V** | Nothing placed; `in conversation` | 2026-11-01 pass |
| C3 | Pause | Open the pause menu, press **V** | Nothing placed | 2026-11-01 pass |
| C4 | Text input | Type text containing "v", "n" or "h" (e.g. a save name) | Nothing placed | 2026-11-08 pass |
| C5 | Menu while holding V/H | Hold **V** (or **H**), open the inventory, wait ~2 s, close it | Nothing placed/deleted; Debug `Last place` / `Last delete`: `cancelled: a menu opened` | 2026-11-03 fail (accepted as a limitation); 2026-11-10 still fails with polled input (V); 2026-11-10 pass with the 0.2 fix (V and H) |
| C8 | Menu tick counter | Watch the Debug `Menu ticks` line in normal play, then open the inventory | Stays still in normal play, grows only while the inventory is open | 2026-11-10 pass |
| C9 | Place feels instant | Hold **V**, release it, turn the camera right after the release | Preview stays until the rune appears at exactly the preview spot, also when turning the camera right after the release | 2026-11-10 pass (also double tap = two runes) |
| C6 | N and H in dialogue | Press **N** and **H** during a dialogue | Symbol unchanged (Debug panel), no rune deleted | 2026-11-08 pass |
| C7 | Esc while holding H/V | Hold **H** (or **V**), press Esc, release the key in the menu, close the menu | Red highlight / preview gone, nothing deleted or placed; Debug `Last delete` / `Last place`: `cancelled: the game was paused`; `Paused time` grew during the menu | 2026-11-03 pass (U/T); 2026-11-10 **fail** with polled input (V/H): placed / deleted after the pause ends; 2026-11-11 pass (V, H; first with Real - Time, then re-tested with Unpaused - Time: pass, normal place unaffected) |
| C10 | Symbol indicator | Hold **V** (turn the mouse wheel), release; later press **N** without V | "Rune: <symbol>" bottom-centre (since 0.2 step 3 a little lower, at 85 % of the screen height) while V is held (with the "(mouse wheel / N)" hint) and for ~1.5 s after N / the wheel, then it disappears | 2026-11-11 pass |
| C11 | N without V: no surface flash | Aim at a wall, press **N** without holding V | Symbol changes (indicator, Debug `Current symbol`), no rune preview appears on the wall | 2026-11-11 pass |
| C12 | HUD host status | Load a save, look at the Debug `HUD indicator` line; open the Esc menu and watch `HUD ticks` | `HUD indicator: yes`, host shows how it was attached (`canvas` / `overlay` / `panel`) and the root class; note whether HUD ticks move during the Esc menu | 2026-11-11 pass (host canvas, root CanvasPanel; HUD ticks also in the Esc menu) |
| C13 | Rune image in the indicator | Hold **V**, turn the mouse wheel through all symbols; press **N** without V; look at the Debug `HUD indicator` line | The rune image of the current symbol shows right above the "Rune: <symbol>" text and changes with the symbol; hidden together with the text; Debug host line has no `icons: ...` part | 2026-11-11 pass (small, clean edges; Debug shows no icon errors) |
| C14 | Indicator hidden in the Esc menu | Hold **V** (indicator shows), press Esc, close the menu while still holding V; then press **N**, press Esc within ~1 s | Indicator (text and rune image) disappears while the Esc menu is open; after closing the menu the indicator shows again while V is held; the ~1.5 s after N does not run down in the menu | 2026-11-11 pass; closing the Esc menu releases V (keys are flushed), so the hold ends there - accepted, very narrow case |

## D. Rune visuals

| ID | Scenario | Steps | Expected | Last run |
|---|---|---|---|---|
| D1 ★ | Rune lies on the surface | Place a rune on rough stone | The rune follows the relief, no square background | 2026-11-03 pass |
| D2 | All 7 symbols | Cycle with **N**, place each with **V** | Correct shapes, no garbage or squares | 2026-11-03 pass |
| D3 | Glow | Place a rune in a dark place (mine, night) | Soft blue light around the rune | 2026-11-08 pass; sometimes too bright in the dark (the Rune glow setting covers it) |
| D4 | Glow setting | Settings → Game → Rune glow: 0, 20, 100 | 0 = no light; 100 = bright but not blinding; placed runes update within ~1 s | 2026-11-03 pass |
| D5 | No crashes | Place 20 runes of different symbols, run around for 5 minutes | No crash | 2026-11-08 pass |
| D6 | Readable on light stone | Place X and the Sun on light masonry | The rune stands out from the joints (dark outline) | 2026-11-03 pass |
| D7 | Overlapping planks / logs | Place a rune across a plank or log seam | Rune visible; a break at the seam is acceptable (decal limit), no strong stretching on the edges | 2026-11-03 pass (breaks on round logs) |

## E. Deleting (H key)

| ID | Scenario | Steps | Expected | Last run |
|---|---|---|---|---|
| E1 ★ | Delete by aiming | Place 3 runes ~1 m apart, hold **H** on the middle one, release | The middle one glows red while H is held, then disappears | 2026-11-03 pass |
| E2 | Miss | Press **H** with no rune within 6° of the crosshair and the aimed point farther than 40 cm from any rune (aiming picks the rune nearest to the crosshair within 6° first, else the one nearest to the aimed point within 40 cm) | Nothing deleted; Debug: `no rune near the aimed point` | 2026-11-03 pass |
| E3 | Not through walls | Rune behind a thin wall, aim at the wall in front of it, **H** | Rune not deleted; Debug: `blocked` | 2026-11-08 pass (hard to see behind the wall, rune not deleted) |
| E4 | Aim ring while H is held | Hold **H** aiming at walls and the floor with no rune nearby, move the camera | A small "O" ring at the aimed point on walls/floor, following it; hidden where nothing is aimed (sky, too far, NPC); Debug `Delete aim: none` when no rune is near | 2026-11-11 pass; the "O" ring reads like a tiny rune, user asks for a smaller filled dot |
| E5 | Pick the rune near the crosshair | Place a rune, hold **H** with the crosshair a little beside it (not on it) | A rune within a few degrees of the crosshair glows red; the aim dot stays at the crosshair; Debug `Delete aim: angle`, angle below the max (6); release deletes that rune | 2026-11-11 pass ("very convenient to hit now") |
| E6 | No delete through a wall | Rune on the far side of a wall (also a thin wall) or behind an NPC; hold **H** with the crosshair on the spot where it is | Nothing selected: no red rune, Debug `Delete aim: none`; release deletes nothing | 2026-11-11 pass |
| E7 | Aim dot never stays | Hold **H** with the aim dot visible, then: release; repeat and open the inventory; repeat and press Esc, close the menu, release | The dot disappears each time and never stays after release/menu/pause | 2026-11-11 pass |
| E8 | Aim dot small and filled (0.2) | Hold **H** aiming at walls and the floor | A small filled dot (light disc with a dark edge, ~5 cm) at the aimed point instead of the "O" ring; it does not look like a rune; Debug `Rune assets` has no `aim dot missing` | 2026-11-11 pass: small filled dot |

## F. Persistence

State is shown in Debug → **Persistence** (`Status: restored N …` after a load, `stored N` after a change).

| ID | Scenario | Steps | Expected | Last run |
|---|---|---|---|---|
| F1 ★ | Save and load | Place 3 runes, save, load | Same 3 runes in the same places, no duplicates | 2026-11-04 pass |
| F2 | Game restart | Like F1, but quit the game completely before loading | Runes in place, no duplicates | 2026-11-04 pass |
| F3 | Re-entering an area | Place a rune, go far away (area unloads), come back | The rune is there, exactly once | 2026-11-04 pass |
| F4 | Deleting persists | Delete a rune, save, load | The deleted rune does not come back | 2026-11-04 pass |
| F5 | Old save without runes | Load a save made before the mod was installed | The save loads without errors | 2026-11-04 pass |

## G. Rune list (Stats page)

| ID | Scenario | Steps | Expected | Last run |
|---|---|---|---|---|
| G1 ★ | List is shown | Place 3 runes, open the Stats page | Section "Runic Markers: 3 / 100" (next line: "Click a rune to delete it.") and 3 buttons "<symbol> - N m", nearest first, with a gap above and below | 2026-11-04 pass |
| G2 | Direction matches the map | — | — | retired 2026-11-04 (direction removed from the list) |
| G3 | Delete from the list | Click one rune button, close the menu | That rune is gone in the world; the list shows one less | 2026-11-04 pass (build before the label fix) |
| G4 | Delete all needs confirmation | Click "Delete all runes" once, wait 6 s | The label returns to "Delete all runes", nothing deleted | 2026-11-08 pass |
| G5 | Delete all | Click "Delete all runes" twice within 5 s | All runes gone; list shows 0 | 2026-11-04 pass (build before the label fix) |
| G6 | List deletions persist | After G3/G5: save, load | Deleted runes do not come back | 2026-11-08 pass |
| G7 | List refreshes | Open Stats, close, walk 20 m, reopen | Distances changed | 2026-11-08 pass |
| G8 | Labels survive a text refresh | Open the rune list, switch the keyboard layout / game language, look at the list | Buttons keep "<symbol> - N m" (before the fix they showed "Confirm") | 2026-11-08 pass |

## Run history

| Date | Set | Build | Result |
|---|---|---|---|
| 2026-11-01 | A1–A2, B1–B2, B4–B7, C1–C3 | `1cdc56a` | pass (aiming without a crosshair is hard → hold-T preview added later) |
| 2026-11-03 | D1, D2 (spike, branch `stage2-decal-spike`) | `38379c5` | pass |
| 2026-11-03 | B1, B2, B11–B13, C7, D4, D6, D7, E1, E2 | `8d1f6b6` | pass; C5 accepted as a known limitation |
| 2026-11-04 | G1, G3, G5 (rune list) | branch `stage4-rune-list` | pass; buttons first showed the default "Confirm" label until labels were re-applied after AddChild |
| 2026-11-04 | F1–F5 | `5d0482e` | pass; one crash while saving, attributed to the game (identical call stack without the mod on 2026-11-03), not reproduced |
| 2026-11-08 | A4 (no `-as-development-mode`, enabled via Mod Management UI; mod still loaded from the repo via `-ModsDirectory`, not from `G1R/Mods`) | `8bb8a7b` | pass |
| 2026-11-08 | A3, B3, B8–B10, C4, C6, D3, D5, E3, G4, G6, G7 | `8bb8a7b` | pass; switching the keyboard layout (CrossOver) disables all game keys, not only ours (not a mod bug), and rune list buttons showed the default "Confirm" label |
