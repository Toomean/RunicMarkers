# Runic Markers — Devlog

A Gothic 1 Remake mod built on the official G1R Modkit (Beta). Author: Reaper.
This is an unofficial modification. It is not made, endorsed or supported by THQ Nordic.

Environment: macOS (Apple Silicon); the game and Unreal Engine run through CrossOver (Wine). No Windows machine.

Only verified results are listed below. Assumptions are marked as such.

---

## 2026-11-01. Stages 0 and 1: the mod loads, a marker gets placed

- The mod package was created with the game's built-in mod manager (`-ModManagementUI`). AngelScript is run with
  `-as-development-mode -ingametools -ModsDirectory=... -Mods=Reaper-RunicMarkers`.
- Pressing T traces from the camera and places a debug marker (a glowing "X") on the hit surface. Verified in-game:
  walls and floors; rejection when too far, on characters, on movable objects and through walls; blocked in the
  inventory, in dialogue and on pause. The mod settings show up in the game's Options.
- First compile error: AngelScript treats unreachable code as an error, and one error disables the whole mod.

## 2026-11-01. Our own symbols

- We draw our own symbols as uneven, hand-scratched strokes: X (visited), O (other mark), sun (Innos),
  crescent moon (Beliar), waves (Adanos), closed eye (the Sleeper), a stick figure.
  They are drawn from scratch; no game assets or third-party drawings are used.

## 2026-11-02. A marker should lie on the surface: decals

- A decal spawned at runtime follows the relief. Verified.
- A PNG loads at runtime (`Rendering::ImportFileAsTexture2D`), but in the game's decal materials it renders as a
  dark or white square.
- Cause: all 56 decal materials in the game sample **virtual textures (VT)**, while a runtime-loaded PNG is a plain
  texture. Verified with a debug panel: `VirtualTextureStreaming = true` on all of them.
- Conclusion: the decal image has to be cooked into a Windows `.pak` in advance.

## 2026-11-02. Cooking for Windows on a Mac through CrossOver

- The Mac build of Unreal 5.4 cannot cook for Windows: it has no WindowsTargetPlatform modules.
- We installed **UE 5.4.4 for Windows** with the Epic Games Launcher in a separate CrossOver bottle.
- The command-line cook (`UnrealEditor-Cmd.exe -run=cook -nullrhi`) crashes inside Wine:
  `Assertion failed: (view->protect & VPROT_SYSTEM), function create_view, file virtual.c, line 1835`.
  The crash is **random**: 50–80% of runs, always within the first ~25 seconds. `-ansimalloc`, `-onethread`,
  disabling Zen and disabling MSync did not help.
- **Workaround:** retry automatically until a run gets through. The first full cook of an empty project took
  53 minutes (shaders through Wine on top of Rosetta); a repeat took 41 seconds.
- Headless Python (`-run=pythonscript`) works too and creates the assets.
  `RunUAT BuildCookRun -dlcname=...` from the modkit docs also works under Wine.

## 2026-11-03. Our own material crashes the game, a virtual texture works

- Our own decal material (plain texture, emission, colour), cooked as the mod's DLC plugin, loads, but using it
  **crashes the game**: `LowLevelFatalError [MaterialShared.cpp:1549] This platform requires cooked packages, and
  shaders were not cooked into this material`. Same with a shared shader library and with inline shaders
  (`bShareMaterialShaderCode=False`).
  *Assumption (unverified):* shaders cooked with stock UE 5.4.4 do not match the game's modified engine.
- **What works:** the `.pak` holds **only a texture cooked as VT**. At runtime it is put into a game decal material
  (`M_Dirt_101`, parameter `Texture`), so the game's own shaders are used.
  **Result in-game: our scratched X lies on the ground as a decal.** Verified.

## 2026-11-03. All 7 symbols work, material emission does not

- All 7 symbols are cooked into one `.pak` (VT) and render cleanly in `M_Dirt_101`. Verified.
- Decals with emission: 41–52 materials based on `M_Base_Decal` with `5 - Emissive Mask`,
  `Emissive Color` (red by default) and `Emissive Intensity` (1 by default).
- In `M_Base_Decal` the rune shape works when the rune is put into every texture slot except `Packed Mask`.
- **No emission**: with `Emissive Intensity` 20 and a bright `Emissive Color` the rune stays white
  (Old Camp emblem and board decals). *Assumption:* emission is behind a static material switch that cannot
  change at runtime.
- MVP decision: the glow comes from a small spot light at the rune (verified in stage 1).
- No script API for on-screen text or a crosshair was found, so the rune preview while holding T acts as the
  crosshair. (`UGothicModExt_WidgetExtension`, which can add widgets to existing game screens, was found later.)

## 2026-11-03. Stage 2 in the main mod, contrast on light stone

- Stage 2 moved into the main mod (commit `c51099e`): holding T previews the rune where you look (doubles as the
  crosshair), releasing places it; Y cycles symbols; holding U makes the targeted rune glow red, releasing deletes
  it. The rune glow is a 0–100 setting.
- Symbol orientation took three in-game iterations: on walls the symbol stands upright, on floors its top points
  away from the player.
- On light brick the white rune blended into the joints. A dark outline of the same stroke width was added
  (`art/gen_symbols.py`, mode `outlined`) and the `.pak` rebuilt with `zsh cook/build.sh`. Verified: more readable.
- Decal projection depth went from 10 to 5 cm, so runes spill less onto the next plank of overlapping hut walls.
  On round logs the symbol still breaks at the seams (a decal limitation).
- Known limitation: opening the inventory while holding T or U places or deletes a rune. Scripts cannot tell that
  the inventory is open.

## 2026-11-04. Stage 3: runes are saved with the savegame

- The modkit has no script-visible way to store arrays, strings or vectors in a save. There are int32 Story
  SaveGame fields and the game's float store `AG1RGameState::SaveWorldFloatData` / `GetWorldFloatData`
  (name key → float), used by the game's puzzles and bosses.
- Verified in-game: a stored value survives save → load and a full restart; it is per save slot (an older save
  reads `NOT FOUND`); a value written but not saved is gone after a load. `float32` precision is ~0.01 cm.
  The mod's start-up code runs once per loaded save.
- Format: each rune is 7 floats (location, rotation, symbol) plus a count, under keys like
  `RunicMarkers_<World>_<i>_<Field>`. The whole list is rewritten after every place or delete.
  On load the mod first removes runes already in the world, then spawns the saved ones.
- Safety: if some runes could not be restored, or the `.pak` with the symbols did not load, the mod stops
  rewriting the list so no saved runes are lost.
- Verified in-game: F1–F5 (save/load, restart, leaving and returning, delete, old save).
- The game crashed once while saving (`EXCEPTION_ACCESS_VIOLATION writing …fff0`, a stack overflow).
  The call stack is identical to a crash on 2026-11-03 00:38 without the mod loaded, and the same kind of crash
  happened 4 more times over six months, all without the mod. So it is a game crash (possibly CrossOver-related),
  not a mod bug. It did not reproduce.

## 2026-11-04. Rune list on the Stats page, English-only repository

- `UGothicModExt_WidgetExtension` (modkit example `Example-StatsPage`) adds a **Runic Markers** section to the
  game's Stats page: one game button per rune ("Sun of Innos - 32 m", nearest first), click = delete;
  "Delete all runes" needs a second click within 5 s. Verified in-game.
- Pitfalls: a parameter named `Name` fails to compile ("shadows class property accessor 'GetName'"); the generic
  button showed its default "Confirm" label until our label was applied after `AddChild` and again on the next
  ticks; the list needed a change counter to pick up new runes.
- Repository docs switched to English.

## Next

- Release preparation: running without debug flags through the Mod Management UI, a test on Windows,
  the mod page, a full manual QA run.

## Notes for the developers (draft)

- The crash while saving, `EXCEPTION_ACCESS_VIOLATION writing …fff0` (stack overflow), also happens without mods.
  Build102, call stack offsets `11daee6 546e9f2 547091f 39553c2 …` (CrossOver on macOS).
- **Map markers.** Could mods get an API for their own points on the world map (add, remove, icon, label)?
  Scripts have no map marker classes or map functions; `W_Map_Main` and `UHUDMapController` are native.
  Runic Markers already stores the world location of every rune in the save, so players would see their marks on
  the map right away. `UGothicModExt_WidgetExtension` can add a widget to the map screen, but without a
  world-to-map coordinate conversion there is no way to place a marker on it.
- Can mods use their own materials? Shaders cooked with stock UE 5.4 crash the game (see above). If a specific
  engine version or setting is required, it would help to document it in `content-cooking.md`.
- The game's decal materials only take VT textures, so a texture loaded at runtime
  (`Rendering::ImportFileAsTexture2D`) does not show in them. A plain (non-VT) texture parameter in at least one
  decal master material would let modders use images loaded at runtime.
