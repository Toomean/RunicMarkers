# Changelog

## 0.2.0 — beta

**Keys changed in 0.2: place V, next symbol N, delete H (was T / Y / U). You can rebind them, or bring back
T / Y / U, in Settings → Game → Runic Markers.** (T is also used by a popular mod.)

- Configurable keys: three key rows in Settings → Game → Runic Markers, styled like the game's own key bindings.
  Click a key box and press the new key: it works at once and is saved. A key already used by another
  Runic Markers key is refused; Esc cancels.
- Mouse wheel changes the symbol while you hold the place key.
- On-screen indicator of the current symbol with its rune image, shown while you hold the place key and briefly
  after a symbol change; hidden while the game is paused.
- Delete aiming: holding the delete key picks the rune nearest to the crosshair (within a few degrees), a small
  dot marks the aim point and the target glows red; never through walls or characters.
- Fixed: opening the inventory or a menu while holding the place / delete key no longer places or deletes a rune.
- Fixed: pausing the game (Esc) while holding the place / delete key cancels the place / delete.

Known limitations: keys are not checked against the game's own key bindings or other mods' keys; if you keep
holding V or H while closing the Esc menu, the hold ends there; runes can break at plank/log seams; runes
can be hard to see on muddy ground; tested only under CrossOver on macOS so far.

## 0.1.0 — beta

First public version.

- Place hand-scratched rune marks on walls and floors: hold **T** to preview (works as a crosshair), release to place.
- 7 symbols, cycled with **Y**: X (visited), O (mark), Sun of Innos, Moon of Beliar, Waves of Adanos,
  Eye of the Sleeper, Human.
- Hold **U** to highlight the targeted rune in red, release to delete it.
- Runes are saved with your savegame (per save slot), up to 100 at a time.
- Rune list on the **Stats** page: delete single runes or all of them.
- Settings: max placing distance, rune glow (0–100).

Known limitations: opening the inventory while holding T/U places or deletes a rune; runes can break at plank/log
seams; runes can be hard to see on muddy ground; tested only under CrossOver on macOS so far.
