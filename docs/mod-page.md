# Mod page draft (Nexus Mods / Steam Workshop)

Draft text for the mod page. Not published. Screenshots (not in git, `dist/screenshots/`, made by
`art/01, 09, 07, 02, 06`; 07 and 09 cropped to hide the `-ingametools` bar):
1. hero by a ruin wall with three runes (main image); 2. all symbols on the ground; 3. marked passages
(X on the floor, O on the wall); 4. O at a corridor entrance; 5. Moon of Beliar glowing in a dark crypt;
6. the rune list on the Stats page (`art/10`, before the header was split into two lines). Later: a short T/Y video.

---

**Name:** Runic Markers

**Short summary (one line):**
Scratch glowing runes onto walls and floors to mark where you have been, what you have looted and where to go next.

---

## Runic Markers

This is an unofficial modification. It is not made, endorsed or supported by THQ Nordic.

The Colony is a maze of caves, mines and huts that all look alike. Runic Markers lets you leave your own marks
in the world: scratch a rune onto a wall or the ground wherever you look, and it stays there, softly glowing.

Some ways to use them:
- mark the passages you have not explored yet, so you come back to them later;
- mark the ground next to chests you have already opened;
- mark a stash, a dangerous spot or the way out of a mine.

### Controls

- **Hold T** — preview the rune where you are looking (works as a crosshair)
- **Release T** — place the rune (a quick tap places it right away)
- **Y** — next symbol
- **Hold U** — the rune you are aiming at glows red; **release U** to delete it

### Symbols

X (visited), O (mark), Sun of Innos, Moon of Beliar, Waves of Adanos, Eye of the Sleeper, Human.

### Features

- Runes stick to walls, floors and rocks; never through walls and never on characters, doors or chests.
- Runes are **saved with your savegame**, each save slot has its own runes.
- Up to 100 runes; when you place more, the oldest one disappears.
- **Rune list** on the Stats page: every rune with its distance, nearest first. Click one to delete it, or delete
  them all.
- The keys do nothing in menus, the inventory, dialogue or on pause.
- Settings (Options → Runic Markers): max placing distance and glow strength (0 turns the glow off).
- No collision, no effect on quests, NPCs or balance.

### Installation

- **Steam Workshop:** subscribe, then enable Runic Markers in the game's Mod Management UI.
- **Manual:** extract the archive into the game's `G1R/Mods/` folder (you should get
  `G1R/Mods/Reaper-RunicMarkers/GothicMod.json`), then enable the mod in the Mod Management UI.

To uninstall, disable or delete the mod. Your saves keep loading: the game shows "This save was made with a
different modlist", choose **Continue anyway** and the runes simply do not appear. Enable the mod again and they come back.

### Known limitations (beta)

- Opening the inventory while holding T or U places or deletes a rune.
- A rune placed across a seam between two planks or logs can look cut.
- Runes placed after your last save are gone when you load, like any other progress.
- Tested on the current game version under CrossOver (macOS). Windows reports are very welcome.

### Source and license

Source code: <GitHub link>. The mod's code and symbol art are MIT-licensed. Gothic 1 Remake and its content belong
to THQ Nordic; the mod uses only the official modkit and requires a legal copy of the game.

Feedback, bugs and screenshots of your runes are welcome in the comments.
