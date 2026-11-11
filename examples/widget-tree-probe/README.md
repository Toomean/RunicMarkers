# Widget tree probe (example)

A small debug helper for Gothic 1 Remake mods (G1R Modkit, UnrealEngine-AngelScript). It attaches to one
game widget class and lists that widget's tree, one line per widget: `name : class (parent: name)`. Nested
user widgets are listed indented under their entry. The list appears in an ImGui debug tool. The probe
changes nothing on the page.

Runic Markers used it to look at the Settings -> Game page before adding its key rows. It is kept here as an
example. It sits outside `Reaper-RunicMarkers/`, so the game never loads it.

## Usage

1. Copy `WidgetTreeProbe.as` into your mod's `Script` folder.
2. Set `AddToWidgetOfClass` in `UWidgetTreeProbeExtension` to the soft class path of the widget you want to
   inspect. The default is `/Game/UI/CoreMenus/Settings/W_SettingsPage_Game.W_SettingsPage_Game_C`
   (Settings -> Game). Optional: change `MaxLines` (400) and `MaxDepth` (4).
3. Make sure your mod is loaded (e.g. `-Mods=<YourMod>` on the command line, or enabled in the Mod
   Management UI), and start the game with `-as-development-mode -ingametools`.
4. Open the target widget in-game, then open WidgetTreeProbe -> Debug in the top menu bar.

The probe runs once in `Initialize` and once more on the first `Tick`, because some widgets are added
after `Initialize`. Each run replaces the stored lines. The lines are kept on the default object of a small
`UObject` class, so the example does not need a subsystem.

## What we learned in-game

- `GetAllWidgets`, `GetParent` and `GetRootWidget` work on game widgets.
- For the nested settings widgets we looked at (settings rows, section header, details panel), the host's
  `GetAllWidgets` did not descend into them. You have to call `GetAllWidgets` on each nested `UUserWidget`
  yourself, which is what the probe does.
- A blueprint widget created with `ConstructWidget` has an empty tree until it is added to a live panel.
- `Log()` output could not be read under CrossOver (no log file). The on-screen Debug tool (ImGui, needs
  `-ingametools`) was the only readout we had. The probe still writes each line to the log too.

## Status

This file is put together from code that was verified in-game in Runic Markers: the probe at commits
`29f6c08` (step 4) and `ff9d6d8` (step 5, nested widgets), its ImGui tool panel, and writing to a class
default object. **The standalone file itself was not compiled as-is.** The parts that differ from the
original are: storage on a class default object instead of the mod's subsystem, its own tool class, and
the recursive helper `ListWidgets`, which opens every nested user widget up to `MaxDepth` (the original
went one level deep, only for settings rows, the section header and the details panel).

Original code:

- `git show 29f6c08:Reaper-RunicMarkers/Script/RunicMarkers/RunicMarkersSettingsProbe.as`
- `git show ff9d6d8:Reaper-RunicMarkers/Script/RunicMarkers/RunicMarkersSettingsProbe.as`
- `git show ff9d6d8:Reaper-RunicMarkers/Script/RunicMarkers/RunicMarkersTool.as` (Debug tool, "Settings page probe" section)
- `git show ff9d6d8:Reaper-RunicMarkers/Script/RunicMarkers/RunicMarkersSubsystem.as` (`SettingsProbeLines`, `SettingsProbeRunCount`)
- Removed in `3737e39`.

## License

MIT, same as the rest of the repository (see `LICENSE` in the repository root).
