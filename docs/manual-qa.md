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
| A2 | Settings in the game menu | Pause → Options → mod section | Max distance and Rune glow are listed | 2026-11-01 pass |
| A3 | Game unchanged without the mod | Remove the launch options, load a save | The save loads, no trace of the mod | 2026-11-08 pass; the game shows "This save was made with a different modlist", Continue anyway loads it (screenshot `art/save-without-mode.png`), runes return when re-enabled |
| A4 ★ | Player-style loading (no development mode) | Launch options `-ModsDirectory="<folder>" -ModManagementUI` only; tick the mod in the Mod Management UI, start, load a save | Mod listed as 0.1.0 with its description; no "Some mods couldn't be loaded"; settings, T/Y/U, rune list and save/load work | 2026-11-08 pass (`8bb8a7b`) |

## B. Placing

| ID | Scenario | Steps | Expected | Last run |
|---|---|---|---|---|
| B1 ★ | Rune on a wall | Stand ~1–2 m from a wall, aim, press **T** | Rune on the wall, aligned with the surface | 2026-11-01 pass |
| B2 ★ | Rune on the floor | Aim at the floor, press **T** | Rune on the floor | 2026-11-01 pass |
| B3 | One rune per press | Hold **T** for 2 seconds, release | Exactly one rune, placed on release | 2026-11-08 pass |
| B4 | Too far | Aim at a wall farther than Max distance (3 m), **T** | Nothing placed; Debug panel: `too far` | 2026-11-01 pass |
| B5 | Not on characters | Aim at an NPC, **T** | Nothing placed; `rejected: character` | 2026-11-01 pass |
| B6 | Not on movable objects | Aim at a movable object (door, item), **T** | Nothing placed; `rejected: non-static` | 2026-11-01 pass |
| B7 | Not through walls | Stand so the camera sees a surface around a corner that the hero does not, **T** | Nothing placed; `blocked` | 2026-11-01 pass |
| B8 | Distance setting | Options → Max distance = 500; repeat B4 | Now the rune is placed | 2026-11-08 pass |
| B9 | 100 rune cap | Place 101 runes | 100 runes; the oldest one disappeared | 2026-11-08 pass |
| B10 | No collision | Place a rune on the floor, walk over it | The hero does not stumble or get stuck | 2026-11-08 pass |
| B11 ★ | Preview | Hold **T** and move the camera | The selected rune follows the aim; it is hidden where placing is not allowed (too far, NPC, through a wall) | 2026-11-03 pass |
| B12 | Orientation on walls | Place the "Human" and the "Moon" on a wall | Upright, not mirrored | 2026-11-03 pass |
| B13 | Orientation on floors | Place the "Human" on the floor facing different directions | The head points away from the player | 2026-11-03 pass |

## C. Keys do nothing in menus

| ID | Scenario | Steps | Expected | Last run |
|---|---|---|---|---|
| C1 ★ | Inventory | Open the inventory, press **T** | Nothing placed | 2026-11-01 pass |
| C2 | Dialogue | Talk to an NPC, press **T** | Nothing placed; `in conversation` | 2026-11-01 pass |
| C3 | Pause | Open the pause menu, press **T** | Nothing placed | 2026-11-01 pass |
| C4 | Text input | Type text containing "t" (e.g. a save name) | Nothing placed | 2026-11-08 pass |
| C5 | Menu while holding T/U | Hold **T** (or **U**), open the inventory, release, close it | **Known limitation:** the inventory sends a key release, so a rune is placed/deleted. Only check that the preview / red highlight does not stay on | 2026-11-03 fail (accepted as a limitation) |
| C6 | Y and U in dialogue | Press **Y** and **U** during a dialogue | Symbol unchanged (Debug panel), no rune deleted | 2026-11-08 pass |
| C7 | Esc while holding U/T | Hold **U** (or **T**), press Esc, release the key in the menu, close the menu | Red highlight / preview gone, nothing deleted or placed | 2026-11-03 pass |

## D. Rune visuals

| ID | Scenario | Steps | Expected | Last run |
|---|---|---|---|---|
| D1 ★ | Rune lies on the surface | Place a rune on rough stone | The rune follows the relief, no square background | 2026-11-03 pass |
| D2 | All 7 symbols | Cycle with **Y**, place each with **T** | Correct shapes, no garbage or squares | 2026-11-03 pass |
| D3 | Glow | Place a rune in a dark place (mine, night) | Soft blue light around the rune | 2026-11-08 pass; sometimes too bright in the dark (the Rune glow setting covers it) |
| D4 | Glow setting | Options → Rune glow: 0, 20, 100 | 0 = no light; 100 = bright but not blinding; placed runes update within ~1 s | 2026-11-03 pass |
| D5 | No crashes | Place 20 runes of different symbols, run around for 5 minutes | No crash | 2026-11-08 pass |
| D6 | Readable on light stone | Place X and the Sun on light masonry | The rune stands out from the joints (dark outline) | 2026-11-03 pass |
| D7 | Overlapping planks / logs | Place a rune across a plank or log seam | Rune visible; a break at the seam is acceptable (decal limit), no strong stretching on the edges | 2026-11-03 pass (breaks on round logs) |

## E. Deleting (U key)

| ID | Scenario | Steps | Expected | Last run |
|---|---|---|---|---|
| E1 ★ | Delete by aiming | Place 3 runes ~1 m apart, hold **U** on the middle one, release | The middle one glows red while U is held, then disappears | 2026-11-03 pass |
| E2 | Miss | Press **U** with the aim farther than 40 cm from any rune | Nothing deleted; Debug: `no rune near the aimed point` | 2026-11-03 pass |
| E3 | Not through walls | Rune behind a thin wall, aim at the wall in front of it, **U** | Rune not deleted; Debug: `blocked` | 2026-11-08 pass (hard to see behind the wall, rune not deleted) |

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
