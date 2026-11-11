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

## 2026-11-08. Release 0.1.0

- Checked without `-as-development-mode`, enabled through the Mod Management UI; the full manual QA passes
  (C5 stays a known limitation).
- The game can reset the generic button labels to "Confirm" (seen after a keyboard layout switch), so labels
  are compared and re-applied every tick. Default glow lowered from 20 to 12.
- Published: GitHub release v0.1.0 and Steam Workshop item 3836204541. The Mod Management UI upload writes the
  Workshop ID, tags, a game dependency and the description into `GothicMod.json` and adds `Preview.jpg`.

## 2026-11-09. Key conflict with "Put Away Torch"

- The popular mod "Put Away Torch" (Workshop 3830047870, ~1,500 subscribers) also uses **T** by default: tap
  draws/stows the torch, hold drops it. With both mods, placing a rune also draws or drops the torch.
- How that mod makes its key configurable (read from its scripts; the mod has no license, so the approach is
  reused, not the code):
  - the key is a `UPROPERTY(Config) FKey` in a `Config=GameUserSettings` class, saved with `SaveConfig()`;
  - the settings page gets a native `UInputKeySelector`, injected into the mod's section of
    Settings → Game (the modkit settings types are only bool, int and float);
  - input is polled every frame (`IsInputKeyDown`, `WasInputKeyJustPressed`) instead of `BindKey`, so a new
    key works at once;
  - texts are localized with a `*.textdb.yaml` file and `LocText("Key")` (see the modkit's localization docs).

## 2026-11-10. 0.2 step 1 verified in-game

- Branch `v0.2-keys`, commit `75abd45`: keys V (place), N (next symbol), H (delete) from config, polled input,
  mouse wheel changes the symbol while V is held. All pass in-game; the wheel does not zoom the camera.
- C5 is not fixed by polling: holding V, opening the inventory and closing it still places a rune.
- The Workshop subscription to our own mod wins over `-ModsDirectory`: the game loaded the Workshop 0.1.0 copy
  (same folder name) instead of the repo. Unsubscribe (or disable it) while testing local builds.
- User wish: show the current symbol on screen (HUD) when it changes, not only as a flash on a surface. The game's
  HUD notifications (`Script/UI/HUDNotificationWidget.as`) are raised from native code only; no script shows how a
  mod can trigger one.
- C5 fix written, **not yet verified in-game**: a released V/H acts only after 0.15 s
  (`ReleaseConfirmDelay`) and is cancelled if `W_ManagementUI_Main` ticked (widget extension
  `URunicMarkersMenuWatch`) since the key was last seen down. Each key keeps its own tick snapshot, taken while
  the key is down, so the cancel also works if the menu pauses world timers. Delete removes the rune that was
  highlighted at the release, it does not re-trace; place still traces at confirm time.
- In-game 2026-11-10: C5 fixed for V and H, C8 passes (the menu tick counter only moves while the inventory is
  open). Delay is visible: the preview disappears, a short gap, then the rune appears. C7 regressed with polled
  input: a key released in the Esc pause menu places / deletes once the pause ends.
- The rune is now placed at the pose computed at the release (no re-trace at confirm) and the preview stays
  until it appears. Verified in-game 2026-11-10: no gap, exact spot, double tap = two runes, C5 still passes.
- Open questions: does the inventory pause world timers? Does the menu widget tick only while open (QA C8)?
  Does the Esc pause menu (C7) still place on release? The C5 fix does not cover it.

## 2026-11-10. 0.2 step 2: C7 and the symbol indicator

Written 2026-11-10; checked in-game 2026-11-11 (results at the end of this section).

- C7 (key released in the Esc pause menu acts after the pause): world timers stop while paused, so the key poll
  sees that release only after unpausing. Each key now also snapshots a "paused time" next to its menu tick
  snapshot (same moment: while the key is down and its action is not pending). At the confirm the action is
  cancelled (`cancelled: the game was paused`) if that value grew by more than 0.05 s
  (`PauseCancelThreshold`). Per the engine field docs `TimeSeconds` stops while paused and is dilated,
  `UnpausedTimeSeconds` is dilated but not paused, `RealTimeSeconds` is neither. The first version used
  `Real - Time` (covers both a real pause and a dilation-to-0 pause, but also grows on time dilation and on frames
  above the engine's frame clamp `MaxUndilatedFrameTime`). After the in-game check (below) paused time is now
  `World.UnpausedTimeSeconds - World.TimeSeconds`, the pure pause part. Debug shows it and, for reference, the
  dilation/clamp part `Real - Unpaused`.
- Symbol indicator (user wish): new `RunicMarkersHud.as`, a widget extension on the HUD notification container
  `W_NotificationMain` (path from the modkit's `Script/UI/GothicHUD.as`). It adds a text block (same
  construction as the Stats page section) with "Rune: <symbol>", shown while V is held (with a
  "(mouse wheel / N)" hint) and for 1.5 s after a symbol change. The root widget type of the host was unknown, so
  it tries canvas (bottom-centre anchors), overlay (bottom-centre alignment with padding), then any panel;
  Debug shows which path was taken, the root class, and a HUD tick counter. When the indicator is attached,
  N no longer flashes the symbol on a surface; the flash stays as the fallback otherwise.
- API evidence: declarations in the game exe strings (Hazelight manual binds): `UWidget GetRootWidget() const`,
  `UWidget ConstructWidget(UClass, FName)`, `float64 GetRealTimeSeconds() const`,
  `float64 GetUnpausedTimeSeconds() const`; UFUNCTION names present: `AddChildToCanvas`, `AddChildToOverlay`,
  `SetAnchors`, `SetAlignment`, `SetAutoSize`, `SetHorizontalAlignment`, `SetVerticalAlignment`, `SetPadding`,
  `SetVisibility`, `ESlateVisibility::HitTestInvisible` / `Collapsed`. Property form `World.TimeSeconds`:
  modkit `Script/AI/CharacterAI_Gothic.as`; `float64` fields: same file. `X.Class.GetName()`: modkit
  `Script/Items/Weapons/Debug/ImGuiDebugTool_ComboAttacks.as`.
- In-game results (2026-11-11): compiles (incl. `FAnchors` fields and the UMG classes). Debug: HUD host
  `canvas` (root `CanvasPanel`), indicator live. "Rune: <symbol>" shows bottom centre while V is held (with the
  "(mouse wheel / N)" hint) and after N. N no longer flashes the symbol on a surface. C7 passes for V and H
  (with `Real - Time`). HUD ticks keep moving during the Esc menu. In the Esc menu only the pause part
  (`Unpaused - Time`) grew (118 -> 182 s); the dilation/clamp part (`Real - Unpaused`) stayed at 16.85 s, but
  had accumulated earlier (loading / hitches), so with `Real - Time` such long frames would cause false cancels.
  The signal was therefore switched to `Unpaused - Time`; re-tested in-game 2026-11-11: C7 passes for V and H, normal placing unaffected (QA C7).

## 2026-11-11. 0.2 step 3: rune image in the indicator

- The indicator sits a little lower (`IndicatorAnchorY` 0.8 -> 0.85; user request after the C10 check). On a
  canvas root the text's top edge is now at the anchor (alignment 0.5, 0.0, was centred), and a `UImage`
  (`RunicMarkersSymbolIcon`, 64 x 64 via `SetDesiredSizeOverride`, alignment 0.5, 1.0) sits right above it.
  It shows the current symbol's rune, follows symbol changes and is shown / hidden with the text. The
  overlay / panel paths keep text only.
- Why separate textures: the decal runes are virtual textures (the game's decal materials sample VT only),
  and UMG brushes most likely cannot draw a VT. `create_vt_symbols.py` now also imports every PNG as
  `T_RuneIcon_<symbol>` (no VT, `TC_EDITOR_ICON` / UserInterface2D, `TEXTUREGROUP_UI`, no mips, sRGB); the
  `RUNIC_OK` line lists both sets with their vt flag. The HUD loads each icon once with `LoadObject` (like the
  decal textures) and caches it. A missing icon only hides the image; Debug's HUD host line then ends with
  `icons: missing (<symbol>)` (or `icons: image not created / attached`).
- API evidence: UFUNCTION names in the game exe strings: `SetBrushFromTexture`, `SetDesiredSizeOverride`
  (UE 5.4: `SetBrushFromTexture(UTexture2D, bool bMatchSize = false)`, `SetDesiredSizeOverride(FVector2D)`).
  `UTexture2D` in script: modkit `Script/UI/InventoryFilters.as`. No modkit script uses `UImage` itself.
- Icon source is downscaled to 128 px by `cook/build.sh` (512 px without mips would alias at 64 px); the import
  script now fails if an asset does not save. Pak rebuilt 2026-11-11 (cook OK on attempt 8 of the wine retries);
  the utoc lists all 7 `T_RuneIcon_*`.
- In-game 2026-11-11: compiles, runes look as before, the icon renders above the text, small with clean edges,
  follows the symbol; the new height is fine; Debug shows no icon errors (QA C10, C13).
- Seen on a screenshot: the indicator stays visible over the Esc pause menu while V is held (the place itself is
  cancelled by C7). Cosmetic, not fixed yet.

## 2026-11-11. 0.2 step 4: delete aiming, indicator hidden on pause

- The HUD indicator (text and rune image) is hidden while the game is paused. The HUD extension still ticks in
  the Esc menu (QA C12), so its Tick compares `GetPausedSeconds()` with the previous tick: if it grew (by more
  than `HudPauseEpsilon`, only against rounding), the game is paused, the indicator hides and the show timer
  after a symbol change does not run down. Should fix (QA C14) the cosmetic issue seen in step 3.
- Delete key (H): aiming at a rune exactly was hard. It now first picks the rune with the smallest angle
  between the view direction and camera -> rune, up to `DeleteAimMaxAngleDeg` (6), within Max distance +
  `DeleteRadius` of the player and in front of the player. Without such a rune, the old rule (nearest to the
  aimed point within 40 cm) is the fallback. Both picks use one helper, `IsRuneVisibleFromCamera`: the rune must
  face the camera (rune X = surface normal, so a rune on the far side of a thin wall is skipped) and a
  Visibility trace from the camera to it must not hit anything more than `DeleteLosTolerance` (5 cm) before it.
  5, not `BlockTolerance` (15, kept for ComputeAim's own LOS): the rune sits 1.5 cm off its surface, so with the
  facing check a clear trace can only end on the rune's own surface; 15 cm let it pick runes just behind thin
  occluders. The fallback used to have no such check, so a rune on the far face of a thin wall within 40 cm of
  the hit point could be deleted; it now skips runes that fail the helper. Release / confirm / cancel logic
  unchanged.
- Visible aim: while H is held, a small "O" (`o_other`) ring, a second `ARunicMarker` like the preview
  (spawned once, light off, actor scale 1 / 0.35 / 0.35 so the decal depth stays), always shows at the aimed
  point (hit-point pose); it does not snap onto the selected rune: the red light already marks the target, and
  two decals on the same spot have an undefined draw order. Hidden on release, when the pending delete resolves
  and when nothing is aimed. Not hidden by the pause (world timers stop, so it stays where it was while the Esc
  menu is open).
- Debug: new line `Delete aim: angle / hit point / none, angle: N deg (max 6), ring pose: yes/no`.
- API evidence: `Math::Acos`, `Math::RadiansToDegrees` (modkit `SoulHarvest_Visual.as:424`), `Math::Clamp` of a
  dot product (`AIState_WatchFight.as:1463`), `GetSafeNormal` (`NativeAICommands.as:1506`), `ActorForwardVector`
  (`PerceptionEventMixins.as:97`), `SetActorScale3D` (`SleeperTempleRegionTraits.as:133`).
- Settings-page probe (discovery only, no behaviour change): `RunicMarkersSettingsProbe.as`, a widget extension on
  `W_SettingsPage_Game_C`, lists its widget tree (name : class (parent)), host class, root class and widget count in
  Debug -> "Settings page probe" (max 200 lines), to learn where a key-binding UI could go. Runs in Initialize and
  once on the first Tick. Investigation so far: the `UGothicModExt_UserSettings` parent chain, the
  `InjectToWidgetWithName` value and the settings row child names are unknown; default asset paths found in the
  exe: `W_SettingsRow`, `W_SettingsSectionHeader`, `W_Setting_Bool` / `Int` / `Float`, `W_SettingsPage_Game`;
  `UInputKeySelector` reflected API present; UObject `SaveConfig` bind present. API: `GetAllWidgets` (Hazelight
  bind string in the exe, no script precedent), `UWidget.GetParent` (UFUNCTION, reflected name in the exe, no
  widget precedent in the modkit) - both UNVERIFIED until compiled (QA A5).
- UNVERIFIED (not compiled, not run): that it compiles; that actor scale shrinks the decal (Y/Z) as expected;
  6 deg and 0.35 feel right; 5 cm `DeleteLosTolerance` does not reject visible runes on grazing floors at long
  range; the pause detection never flickers in normal play (QA C14, E4-E7); the probe's widget path and world:
  the settings page may be created in the main-menu world, where `URunicMarkersState` may not be the in-game one,
  so the Debug lines may stay empty in game (the lines are also in the log, `[RunicMarkers][SettingsProbe]`; QA A5).

- In-game 2026-11-11: compiles (incl. `GetAllWidgets`, `UWidget.GetParent`); ring at the aim point, picking a
  rune near the crosshair "very convenient"; no delete through walls (E6); the ring never stays (E7); indicator
  hidden in the Esc menu (C14; closing the menu releases the held V, accepted). User: the ring looks like a tiny
  rune, wants a smaller filled dot.
- Settings page tree (W_SettingsPage_Game_C, root GridPanel): GridPanel_26 > VerticalBox_Center > ScrollBox_Content
  > VerticalBox_Content, which holds the game rows (SettingsRow_CameraPreset ... : W_SettingsRow_C) and, after
  them, the mod section: W_SettingsSectionHeader_C_<n> plus one W_SettingsRow_C_<n> per mod setting. Also
  W_SettingsDetails (W_SettingsDetails_C) on the GridPanel. Inside W_SettingsRow_C: unknown yet.

## 2026-11-11. 0.2 step 5: aim dot, key rows prototype

- Aim dot instead of the "O" ring (the user: the ring reads like a tiny rune). `art/gen_symbols.py` got `MARKS`,
  helper marks that are not placeable symbols: `dot`, a filled disc with an uneven hand-cut rim, written only in
  the "outlined" style (white fill, dark edge), not on the sheet. PNG: `rsvg-convert art/symbols/outlined_dot.svg
  -o art/symbols/outlined_dot.png` (Homebrew librsvg). Evidence that this is how the committed PNGs were made:
  `rsvg-convert art/symbols/outlined_o_other.svg` gives a byte-identical file, and `gen_symbols.py OUT 1`
  regenerates every committed SVG byte-identically. `cook/build.sh` copies it as `rune_dot.png`;
  `create_vt_symbols.py` imports it as `T_Rune_dot_VT` only (VT, no HUD icon).
- Script: `RunicMarkers::DeleteAimMarkId = "dot"`, `DeleteAimScale` 0.35 -> 0.2. `LoadSymbolMaterials` builds one
  more MID of the same decal material with the dot texture (`DeleteAimMaterial`), outside `SymbolMaterials`, so
  `SymbolIds` / `SymbolNames`, the mouse wheel, saves and the Stats page never see it. Missing dot texture:
  `Rune assets` in Debug ends with `; aim dot missing` and no aim mark shows (deleting still works).
- Settings probe: `MaxLines` 400; for every widget whose class starts with `W_SettingsRow_C`,
  `W_SettingsSectionHeader_C` or `W_SettingsDetails` it also lists that widget's own `GetAllWidgets()`, indented,
  to learn what a game settings row is made of (for a later look that matches the game).
- Key rows prototype (`RunicMarkersKeyRows.as`, built from the probe extension's Initialize, after the first probe
  run): appended to `VerticalBox_Content` (found with `GetWidgetFromName(n"VerticalBox_Content", UPanelWidget)`,
  as the Stats page finds `ScrollBox_Content`), per key a label "Runic Markers: Place key" / "Next symbol key" /
  "Delete key" (`UAlkRichTextBlock`, TS_Dialogue, as the Stats page) and below it a UMG `UInputKeySelector`
  (no modifiers, no gamepad, Escape = escape key, "Press a key..."). Label above the selector, not side by side:
  no horizontal box precedent yet. `OnKeySelected` -> one `URunicKeyRowHandler` per row (pattern of
  `URunicRuneButtonHandler`): rejects invalid keys, Escape, left / right mouse button and a key that another of
  our three keys already uses (the selector shows the old key again); otherwise writes the field of the
  `URunicMarkersKeyConfig` default object and calls `SaveConfig()`. Key polling reads that object every poll, so
  the new key works at once. Widgets are looked up by name first, so a second Initialize on the same page does
  not add them again (it binds new handlers to the existing selectors; handlers are idempotent). No
  `VerticalBox_Content` = nothing added, status says so. Debug: `Key rows: <status>` (e.g. `place key set to
  B`); also logged as `[RunicMarkers][KeyRows]`.
- Writing the default object: `RunicMarkers::GetKeyConfigForWrite()` =
  `Cast<URunicMarkersKeyConfig>(URunicMarkersKeyConfig::StaticClass().GetDefaultObject())`: `UClass` bind
  `UObject GetDefaultObject() const` (exe) with the modkit precedent `SkillClass.Get().GetDefaultObject()`
  (`GASCharacterStateMixins.as:931`), a plain non-const object. Writes through `URunicMarkersKeyConfig.DefaultObject`
  have no precedent (only reads), so reads keep that form and writes use this one; both are the same object.
- API evidence (exe strings): `UInputKeySelector` reflected `SetSelectedKey(InSelectedKey)`, `OnKeySelected`
  (`OnKeySelected__DelegateSignature`, param `SelectedKey`), `SetEscapeKeys(InKeys)`, `SetAllowModifierKeys`,
  `SetAllowGamepadKeys`, `SetKeySelectionText`; `FInputChord` Hazelight constructor `(const FKey& Key)`;
  `FKey opEquals`; `const FKey Escape / LeftMouseButton / RightMouseButton`; `Key_IsValid` (same library as the
  compiled `Input::Key_GetDisplayName`); UObject `void SaveConfig()`; `FString StartsWith` (modkit
  `ImGuiDebugTool_ComboAttacks.as:661`).
- In-game run (2026-11-11): compiles with no error; `UInputKeySelector` is usable from script, `OnKeySelected`
  binding works. E8 pass: small filled dot. A6 pass: the three rows (selectors V / N / H) sit above the
  "[Mod] Runic Markers" section header, between the game's telemetry row and the mod section (the modkit adds
  its section after our extension has appended rows). Look: engine default style (grey full-width bars, cyan
  Roboto key text, label above the bar), very different from the game's `W_SettingsRow` (art/06); accepted as a
  prototype. A7 pass: rebinding place to B works at once. A8 pass: Next symbol -> H is rejected and reverts to
  N (`SetSelectedKey` inside `OnKeySelected` sticks). A9 pass: Esc while listening cancels, the settings menu
  stays open. A10 pass: the binding survives a restart (`GetDefaultObject()` write + `SaveConfig()` persist, the
  default object loads the ini at startup).
- Probe run 2 (art/07, art/08): 94 lines, root GridPanel, 25 widgets. Game row `W_SettingsRow_C` (e.g.
  `SettingsRow_CameraPreset`, `_TextLanguage`, `_AudioLanguage`, `_ShareTelemetryData`; mod rows are
  `W_SettingsRow_C_<n>`): `Overlay_1` > `HorizontalBox_230` (`Image_Hover_Left`, `Spacer_44`, `Image_Hover_Right`)
  and `HorizontalBox_Content` > (`ScaleBox_208` > `Text_Name` : TextBlock) and (`SizeBox_SettingsEntry` : SizeBox >
  `W_Setting_Enum_C` / `W_Setting_Bool_C` / `W_Setting_Float_C`). Section header `W_SettingsSectionHeader_C_<n>`:
  `HorizontalBox_0` > `TextBlock_Title` : TextBlock, `Image_Line_Right` : Image. `W_SettingsDetails`
  (`W_SettingsDetails_C`, parent `GridPanel_26`): `VerticalBox_Content` > `TextBlock_Title`, `ScaleBox_Image` >
  `Image_Example`, `AlkRichTextBlock_Description` : AlkRichTextBlock. Our `RunicMarkersKeyLabel_i`
  (AlkRichTextBlock) and `RunicMarkersKeySelector_i` (InputKeySelector) are in `VerticalBox_Content`, listed before
  the mod section header. Evidence for the restyle: a game row is an Overlay with hover images and a
  name + SizeBox entry in a HorizontalBox.
- Still UNVERIFIED: `Key_IsValid` use is compiled but its edge cases were not tried; how the dot looks on all
  surfaces beyond the E8 check.

## 2026-11-11. 0.2 step 6: key rows as game settings rows

- Key rows (`RunicMarkersKeyRows.as`) are now the game's own `W_SettingsRow_C` (class path verbatim from the exe
  strings, offset 146526104: `/Game/UI/CoreMenus/Settings/W_SettingsRow.W_SettingsRow_C`), constructed like the
  Stats page builds `W_GenericButton` (`TSoftClassPtr` + `FAssetPreload::BlockingLoad` + `ConstructWidget` on the
  host). Per key: `Text_Name` = "Place key" / "Next symbol key" / "Delete key" (the section header already says
  Runic Markers); our `UInputKeySelector` goes into `SizeBox_SettingsEntry`, found as a `UPanelWidget`, with
  `ClearChildren()` + `AddChild()`. Handlers, validation and `SaveConfig` are unchanged.
- When: the modkit adds the "[Mod] Runic Markers" section after the page's Initialize, so the rows are no longer
  built in Initialize. The probe extension's Tick looks for a `W_SettingsSectionHeader_C` whose `TextBlock_Title`
  contains "Runic Markers" and builds the rows once (per page instance) on the first tick where it exists and the
  child count of `VerticalBox_Content` has stayed unchanged for 2 ticks (so the section's rows are in), appended
  at the end of `VerticalBox_Content`; they are never moved. Not ready after 300 ticks: appended at the end
  anyway, the status says `mod section header not found after N ticks, appended at the end` or `page child count
  not stable after N ticks, appended at the end`.
- Never constructed twice: a key whose row `RunicMarkersKeyRow_<i>` (or fallback selector) is already on the page
  (Initialize ran again on the same widget) is reused; a reused row without our selector
  `RunicMarkersKeySelector_<i>` is logged and skipped (`skipped: N`), no new widget with the same name.
- Fallback, decided once per build: row class not loaded, or the first constructed row lacks `Text_Name` /
  `SizeBox_SettingsEntry` = the step 5 layout (label above the selector) for every key still to build;
  TS_Dialogue is loaded only then. The build status says `FALLBACK layout for N: <reason>`, and the handler
  statuses (rebind results) of those keys end with `[FALLBACK layout]` (Debug shows only the latest status).
- After the build, every tick: the row names are re-applied where they differ (three text compares; the row
  blueprint may reset `Text_Name` on page reopen / tab switch without a new Initialize), and a cheap guard
  sets the status `WARNING: <key> row entry no longer holds our key selector` if an
  entry has no child or another first child (no rebuild).
- No text style this step. The step 6 plan copied the game row's font / color into the selector with
  `UInputKeySelector.SetTextStyle`, but in UE 5.4 that function has no UFUNCTION (InputKeySelector.h:140); the exe
  string `SetTextStyle` (131862472) is `UMultiLineEditableTextBox`'s (MultiLineEditableTextBox.h:124), so the call
  would not compile. Dropped; the key box keeps the engine look. Styling waits for the discovery of the game's
  own key selector. Fact for later: `UTextBlock.Font` and `.ColorAndOpacity` are `BlueprintReadWrite, Getter,
  Setter` (TextBlock.h:39, :48), deprecated for direct access since 5.1.
- Discovery (probe, no visible UI): constructs one `W_Setting_KeyMapping_KeySelector_C` (path from the pak
  listing, `_C` class name assumed) on the host once per page instance, lists its `GetAllWidgets` (`game key
  selector: ...`, inner widgets as name : class (parent), so an `InputKeySelector` inside shows up by name).
  Discovery only: for the listing it is added to `VerticalBox_Content` collapsed and removed again right after
  (see the run 1 lesson below). After the build, Tick adds a probe line (and log line) `hover row 0: left ... /
  right ...` whenever the visibility of `Image_Hover_Left` / `Image_Hover_Right` of our row 0 changes, to learn
  how hover is driven.
- API evidence: UE 5.4 headers (UMG/Public/Components) give the UFUNCTION specifiers: `UPanelWidget`
  `GetChildrenCount`, `GetChildAt`, `AddChild`, `ClearChildren` (PanelWidget.h:27, :35, :58, :107);
  `UWidget.GetVisibility`, `GetRenderOpacity` (Widget.h:571, :583); `UTextBlock.SetText` (TextBlock.h:102). Exe
  strings: `ClearChildren` 131792432, `GetChildAt` 131805328, `GetChildrenCount` 131806008, `AddChild` 131791952,
  `GetVisibility` 131529776, `GetRenderOpacity` 131782472, `ESlateVisibility::*` 131691552-131691688;
  `FString Contains` Hazelight bind 137525824; `UUserWidget ConstructWidget(UClass, FName)` 137620496,
  `GetAllWidgets` 137620624, `GetWidgetFromName(Name, WidgetClass)` 146454880 and `(Name)` 146454824;
  `FAssetPreload BlockingLoad(const TSoftClassPtr<UObject>&)` returns `TSubclassOf<UObject>` 146533664;
  `W_SettingsSectionHeader_C` path 146526176. Script precedents: `GetWidgetFromName(..., UPanelWidget)`
  (RunicMarkersStatsPage.as:66), `TSoftObjectPtr` by-value parameter (modkit ImGuiDebugTool_ComboAttacks.as:707).
- Also: the "ring" comments for the delete aim mark (a dot since step 5) fixed in RunicMarkersSubsystem.as and
  RunicMarkersHud.as; QA E5 / E7 say dot.
- In-game run 1 (2026-11-11): compiles. `Key rows: rows added: 3, reused: 0, skipped: 0, FALLBACK layout for 3:
  row lacks Text_Name / SizeBox_SettingsEntry; after the mod section ...`: the (fallback) rows now sit after the
  "[Mod] Runic Markers" section, so the wait for header + stable child count works. Rebind (A7), duplicate
  reject (A8), Esc cancel (A9) and reopening the page (no duplicates) OK. Probe: `game key selector:
  W_Setting_KeyMapping_KeySelector_C, widgets: 0`, so the class path loads. No hover lines (fallback, expected).
- Lesson / fix: a blueprint user widget freshly made with `ConstructWidget` has an empty widget tree until it is
  added to a live panel (`GetWidgetFromName` / `GetAllWidgets` find nothing; same lesson as the Stats page button
  labels, RunicMarkersStatsPage.as:48-50). Fix: `BuildKeyRows` adds the row to `VerticalBox_Content` first, then
  looks up `Text_Name` / `SizeBox_SettingsEntry` (missing after that: `RemoveFromParent` and the fallback; a row
  whose selector could not be made is removed again too), then puts the selector in and sets the name. The
  discovery widget is added collapsed (`SetVisibility(ESlateVisibility::Collapsed)`) before listing and removed
  after. Not run in-game yet.
- In-game run 2 (2026-11-11, user screenshots): compiles. Settings -> Game shows three game-style rows "Place
  key" / "Next symbol key" / "Delete key" (name left, grey engine key box right) inside the mod section, after
  'Max marker distance' / 'Rune glow'. `Key rows` is `not built` until Settings is opened, then `rows added: 3,
  reused: 0, skipped: 0, game rows; after the mod section (tick 3) (keys: B / N / H)`. Rebind, duplicate reject,
  Esc cancel, reopen / tab switch (no duplicates, names kept) and "click a key box, hover another row, press a
  key" all OK. Probe: `RunicMarkersKeyRow_0..2 : W_SettingsRow_C`, each with `RunicMarkersKeySelector_<i>` inside
  `SizeBox_SettingsEntry`.
- Verified by run 2: the row tree is filled right after `AddChild` (lookups in the same call work); the
  stable-count build puts our rows after the section's rows; the row names are kept on reopen / tab switch; the
  row blueprint works without a setting object behind it as far as visible: nothing showed in Debug (there is
  no log file available under CrossOver, so "no Accessed None" only means nothing visible in Debug).
- Hover: on our row 0 the row blueprint itself toggles `Image_Hover_Left` / `Image_Hover_Right` between `Hidden`
  (opacity ~1.0) and `SelfHitTestInvisible` (opacity 0.0) as the mouse moves, so hover is driven by the row;
  no page list / extra code needed.
- Game key selector: `W_Setting_KeyMapping_KeySelector_C, widgets: 7 (added collapsed)`: `SizeBox_Content` >
  `Overlay_Content` > (`ScaleBox_KeySelector` > `InputKeySelector` : InputKeySelector) and (`ScaleBox_Icon` >
  `Border_Icon` > `Image_Icon` : Image). The game's key box is an engine `UInputKeySelector` inside a styled
  wrapper, so it can likely be reused (step 7).
- Still UNVERIFIED: that no other mod's section follows ours (then our rows would sit after that one); focus /
  gamepad navigation of our rows.

## 2026-11-11. 0.2 step 7: the game's key box in our rows

- Our three rows now hold the game's own key box `W_Setting_KeyMapping_KeySelector_C` (the widget of the Key
  Bindings page; tree from step 6 run 2: `SizeBox_Content` > `Overlay_Content` > (`ScaleBox_KeySelector` >
  `InputKeySelector` : InputKeySelector) and (`ScaleBox_Icon` > `Border_Icon` > `Image_Icon` : Image)) instead of
  our engine-styled `UInputKeySelector`. `BuildKeyRows`: after the row is in `VerticalBox_Content`, construct
  `RunicMarkersKeyWidget_<i>` on the host, `ClearChildren` + `AddChild` it into the row's `SizeBox_SettingsEntry`
  (live panel first: the step 6 lesson), then `GetWidgetFromName(n"InputKeySelector", UInputKeySelector)` on it
  and give that inner selector our setup (no modifiers / gamepad, Escape as escape key, "Press a key...",
  `SetSelectedKey(current)`, our `OnKeySelected` handler). Our handler stays the source of truth (validation,
  revert via `SetSelectedKey`, `SaveConfig`).
- Key box fallback, decided once: class not loaded, its `ConstructWidget` failed, or no inner `InputKeySelector`
  after adding (that widget is removed again) = this and every later key get our engine selector in the row.
  Status: `game key box: N` plus, if any, `engine key box: M (<reason>)`; both counted when a box is created or
  reused.
- Rebind: after a valid key is stored and saved, `SetSelectedKey(new key)` on the selector, so a blueprint
  `OnKeySelected` on the game box that changes the shown key cannot leave it wrong. `SetSelectedKey` fires
  `OnKeySelected` again (seen in step 5), so `ApplySelectedKey` returns at once when the key equals the current
  one: no loop, no second save. No per-tick key re-apply (it would re-fire `OnKeySelected` every tick; reading
  the `SelectedKey` property is unverified); QA A12 checks reopen / tab switch instead.
- Reuse (Initialize again on the same page): a row's `RunicMarkersKeyWidget_<i>` (and its inner selector) or our
  `RunicMarkersKeySelector_<i>` is looked up inside the row; nothing with the same name is constructed again.
  The per-tick entry guard now checks for the widget we put into the entry (game key box or our selector);
  the extension keeps it in `m_KeyRowEntryWidgets`.
- Probe: the separate discovery key box (constructed, added collapsed, removed) and the hover lines are gone
  (findings recorded in step 6). New discovery line on the tick probe run: `our game key box 0: <class>, widgets:
  N, Image_Icon: <visibility, opacity>` plus its inner tree, since the page / row listings do not descend into the
  key box's own tree.
- Evidence: no new API. Everything used is from step 6 (verified in-game): `ConstructWidget`, `AddChild`,
  `ClearChildren`, `RemoveFromParent`, typed `GetWidgetFromName(..., UUserWidget / UInputKeySelector)`
  (FindRow, step 6), the `UInputKeySelector` UFUNCTIONs (InputKeySelector.h:88, :95, :109, :116, :153) and
  `OnKeySelected` (BlueprintAssignable, :80). Class path `W_Setting_KeyMapping_KeySelector_C` loaded in step 6
  run 2. Exe strings for a setting object: the game's settings widgets have a native base
  (`G1R/UI/Settings/Objects/SettingObjectWidget.h`, 145935408) with `SetSettingObject` (145921832, param
  `_Setting`), `m_Setting` / `m_GenericSetting`, and `ESettingsType::KeyMapping` (145956136); no class name for
  the key mapping widget itself was found. So the key box blueprint may well expect a key-mapping setting object
  that we do not give it.
- In-game run (2026-11-11, art/09, art/10): compiles. Settings -> Game: our three key boxes are the game's key
  boxes (dark box with a light frame, game font, keys V / N / H shown, not "None"), matching the Key Bindings
  page; the row hover highlight shows on our rows (Delete key highlighted in art/10). Debug: `Key rows: rows
  added: 3, reused: 0, skipped: 0, game rows, game key box: 3; after the mod section (tick 3) ...`. Probe: `our
  game key box 0: W_Setting_KeyMapping_KeySelector_C, widgets: 7, Image_Icon: SelfHitTestInvisible ...`; no icon
  is visible in the box, only the key text. Rebind (A7), duplicate reject (A8), Esc cancel (A9) OK; reopen / tab
  switch: the boxes keep the current keys (user: "seems OK").
- Verified by this run: the key box blueprint works without a setting object as far as visible (no errors in
  Debug, no "None" key, Construct does not reset our key); the inner selector setup and our `OnKeySelected`
  handler work (validation, revert, save).
- Still UNVERIFIED: whether the blueprint binds its own `OnKeySelected` (e.g. to write a game key mapping) in a
  way that matters (nothing visible so far; our `SetSelectedKey` after saving covers the shown key); whether it
  overrides `SetKeySelectionText` / `SetEscapeKeys` on the inner selector (Esc cancel works); reopen / tab switch
  only checked briefly.

## 2026-11-11. 0.2 step 8: settings probe removed

- The settings page probe has done its job and is deleted (not gated): `RunicMarkersSettingsProbe.as` is now
  `RunicMarkersKeyRowsPage.as` (`git mv`) with the extension class `URunicMarkersKeyRowsPage`. It keeps only what
  the key rows need: `AddToWidgetOfClass` W_SettingsPage_Game, Initialize resetting the per-instance state, Tick
  (`TryBuildKeyRows`, then `ApplyRowLabels` and `CheckEntries`), the row / key box class loads and the TS_Dialogue
  fallback.
- Removed: the widget tree listing (`RunProbe`, `AddLine`, `IsFull`, `MaxLines`, `ShouldListInner`,
  `DescribeWidget`), the discovery lines (`AddDiscoveryLines`, `VisibilityText`, the `our game key box` line), the
  `[RunicMarkers][SettingsProbe]` log lines, `SettingsProbeLines` / `SettingsProbeRunCount` in the subsystem and
  the "Settings page probe" section of the Debug panel. The `Key rows:` status line stays in Debug.
- Its findings stay recorded in steps 4-7 (page tree, row / header structure, hover, the game key box tree).
- UNVERIFIED (QA A13, not run yet): that it compiles and the key rows behave as before.

## 2026-11-11. 0.2.0 release prep (docs)

- Step 8 checked in-game: QA A13 pass (user: "everything works").
- `GothicMod.json` description (`modVersion` already 0.2.0), README, CHANGELOG (0.2.0 entry) and
  `docs/mod-page.md` (incl. a ready-to-paste Workshop change notes block) updated for 0.2.0. Their first line is
  the key change notice (user decision 2026-11-11): "Keys changed in 0.2: place V, next symbol N, delete H (was
  T / Y / U). You can rebind them, or bring back T / Y / U, in Settings → Game → Runic Markers." The
  `GothicMod.json` text stays ASCII like before ("Settings > Game > Runic Markers", " - " dashes), no GitHub link.
- New in the texts: V / N / H, mouse wheel, symbol indicator, delete aiming with the aim dot, the key rows; C5
  (menu while holding a key) and C7 (pause while holding a key) are fixed, no longer limitations. Limitations
  now: no clash check against the game's or other mods' keys; holding V or H while closing the Esc menu ends the
  hold (C14; H by the same key poll as V); plank / log seams, mud; CrossOver only.
- `docs/manual-qa.md`: scenario steps / expectations use V / N / H (Last run entries kept as played); A4
  expects 0.2.0; A13 pass.
- User answers (2026-11-11): the English menu is "Settings" (art/11.png: Settings → GAME tab with the "[Mod] Runic
  Markers" section and the key rows), so the texts say "Settings → Game → Runic Markers"; published texts do not
  name the other mod ("T is also used by a popular mod"); the 0.1 Workshop text was pasted from
  `dist/workshop-description.txt`, which is now regenerated from the `GothicMod.json` description (LF endings).

## Next

- For the user, to release 0.2.0: commit; rebuild the `.pak` if needed (`zsh cook/build.sh`);
  `zsh tools/package.sh`; QA smoke set (★) and A4 with the packaged build; upload to the Workshop, paste the
  description from `dist/workshop-description.txt` and the change notes from `docs/mod-page.md`; add
  `art/11.png` (English key rows) and other new screenshots to the gallery if wanted.
- Later: maybe localization (German, Polish, Russian), a placement effect and sound, adaptive glow, a better
  Workshop preview image.
- A test on Windows.

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
