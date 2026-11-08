# Runic Markers (Gothic 1 Remake mod)

This is an unofficial modification. It is not made, endorsed or supported by THQ Nordic.

Scratch rune marks onto walls and floors wherever you look: "I was here", a stash, danger, a shrine.
The symbols are hand-drawn and look carved into the surface.

## Controls

| Key | Action |
|---|---|
| **T** (hold) | Preview the rune where you are looking (works as a crosshair) |
| **T** (release) | Place the rune. A quick tap places it right away |
| **Y** | Next symbol (shown for ~1 s where you are looking) |
| **U** (hold) | The rune that would be deleted glows red |
| **U** (release) | Delete that rune (the one nearest to the aimed point, within ~40 cm) |

Symbols in order: X (visited), O (mark), Sun of Innos, Moon of Beliar, Waves of Adanos, Eye of the Sleeper, Human.

Placing rules:
- only on **static** world geometry (walls, floors, rocks), not on characters, doors or chests;
- no farther than **Max distance** (300 cm by default) and not through walls;
- the keys do nothing in menus, the inventory, dialogue or on pause;
- at most 100 runes; when full, the oldest one disappears.

Runes are **saved with your savegame**: they come back after loading and after restarting the game, and every save
has its own runes. Like any progress, runes placed after your last save are gone when you load.

### Rune list

Open the **Stats** page: the **Runic Markers** section lists your runes, nearest first, with their distance.
Click a rune to delete it. **Delete all runes** asks for a second click.

## Settings

Pause → Options → **Runic Markers**:
- **Max marker distance (cm)**: 100–1000, default 300;
- **Rune glow (0-100)**: light around the runes, 0 turns it off. Placed runes update within about a second.

## Installation

Copy the `Reaper-RunicMarkers` folder into the game's `G1R/Mods/` folder and enable it in the Mod Management UI.

For development, run the mod straight from this repository with these Steam launch options:

```
-as-development-mode -ingametools -ModsDirectory="<path to this repository>" -Mods=Reaper-RunicMarkers
```

`-ingametools` adds the debug panel **RunicMarkers → Debug**.

Package contents: the scripts (`Script/RunicMarkers/*.as`) and
`Content/Paks/Windows/Reaper-RunicMarkerspakchunk0-Windows.*` (the 7 symbols as virtual textures). Without the
`.pak`, runes cannot be placed and the debug panel shows `Rune assets: FAIL`.

## How the runes work

The game crashes on materials cooked by mods (`shaders were not cooked into this material`), so a rune is the game's
own decal material `M_Dirt_101` with our symbol texture plugged in. The texture is cooked into the `.pak` as a
virtual texture, because the game's decal materials only accept virtual textures. The glow is a small spot light at
the rune: the emissive parameters of the game's decals had no visible effect.
Details and history: [`docs/devlog.md`](docs/devlog.md).

### Rebuilding the `.pak` (macOS + CrossOver)

Requires Unreal Engine 5.4 for Windows in the CrossOver bottle "Epic Games Store".

```
zsh cook/build.sh
```

The script copies the `cook/RunicDecal` project and the PNGs from `art/symbols/` into the bottle, imports them as
virtual textures, cooks the DLC plugin with `RunUAT BuildCookRun -dlcname=Reaper-RunicMarkers` and installs the
`.pak` into the mod. Wine randomly crashes on Unreal start-up (`create_view` assertion), so every step is retried up
to 15 times.

## Packaging a release

```
zsh tools/package.sh
```

Builds `dist/Reaper-RunicMarkers-<version>.zip` from the committed `Reaper-RunicMarkers/` folder
(version from `GothicMod.json`). See [`CHANGELOG.md`](CHANGELOG.md).

## Testing

Manual scenarios: [`docs/manual-qa.md`](docs/manual-qa.md). The smoke set is marked ★.

When reporting a problem, please include:
1. the text or a screenshot of any AngelScript error window (file:line);
2. a screenshot of **RunicMarkers → Debug**, especially `Rune assets`, `Last place`, `Last preview`, `Last delete`
   and `Persistence`;
3. what you were aiming at.

## Known limitations

- Opening the inventory while holding T or U places or deletes a rune: the game sends a key release, and scripts
  cannot tell that the inventory is open.
- On overlapping planks and round logs the symbol can break at the seams (decal projection).
- Tested only under CrossOver on macOS so far, not on Windows.
- Runes are not shown on the world map: the modkit has no map API yet.

## License

The mod's own code, scripts and rune artwork are released under the [MIT License](LICENSE).

This license covers only what this repository adds. Gothic 1 Remake, its modkit and all game content belong to
THQ Nordic GmbH and its licensors and are governed by the game's EULA and the
[THQ Nordic Modding Policy](https://github.com/AlkimiaInteractive/G1R-Modkit/blob/main/LICENSE.txt). The mod needs an
installed, legitimately owned copy of the game, is free of charge, and grants THQ Nordic the licence described in
section 4.3 of that policy.

This is an unofficial modification. It is not made, endorsed or supported by THQ Nordic.
