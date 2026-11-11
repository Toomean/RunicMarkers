#!/bin/zsh
# Rebuilds the rune pak (7 symbols as virtual textures for the decals + the same 7 as plain UI icons for the
# HUD indicator, + the delete aim dot as a VT only) on macOS via CrossOver + Windows UE 5.4.4.
# Usage: zsh cook/build.sh            (from the repo root)
# Needs: CrossOver bottle "Epic Games Store" with UE 5.4 at C:\Program Files\Epic Games\UE_5.4.
# The wine "create_view" assertion crash is random (~50-80% of runs), so every step is retried.
set -u
repo_root=${0:A:h:h}
bottle_c="$HOME/Library/Application Support/CrossOver/Bottles/Epic Games Store/drive_c"
project_dir="$bottle_c/RunicCook/RunicDecal"
wine_bin=/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/bin/wine
log_dir=$(mktemp -d)
echo "logs: $log_dir"

# 1. Sync the project and the symbol PNGs into the bottle.
mkdir -p "$project_dir/Source_PNG" "$project_dir/Plugins/Reaper-RunicMarkers/Content/Textures"
cp -R "$repo_root/cook/RunicDecal/." "$project_dir/"
# Source art: white stroke with a dark carved edge (art/gen_symbols.py, mode "outlined"); the dark edge
# keeps runes readable on light stone. Copied under one neutral name so the import script does not care:
# rune_<sym>.png (full 512 px, VT decal source) and icon_<sym>.png (downscaled to 128 px for the HUD icon,
# which is drawn at 64 px without mips; the full-size source would alias).
for sym in x_visited o_other innos beliar adanos sleeper human; do
  cp "$repo_root/art/symbols/outlined_$sym.png" "$project_dir/Source_PNG/rune_$sym.png" || exit 1
  sips -z 128 128 "$repo_root/art/symbols/outlined_$sym.png" --out "$project_dir/Source_PNG/icon_$sym.png" \
    >/dev/null 2>&1 || { echo "sips failed for $sym" >&2; exit 1; }
done
# Delete aim dot (art/gen_symbols.py MARKS, not a placeable symbol): VT decal source only, no icon.
cp "$repo_root/art/symbols/outlined_dot.png" "$project_dir/Source_PNG/rune_dot.png" || exit 1

# 2. Import per symbol (headless python): rune_<sym>.png -> T_Rune_<sym>_VT (virtual texture, decals) and
#    icon_<sym>.png -> T_RuneIcon_<sym> (128 px non-VT UI texture, HUD indicator image). RUNIC_OK lists both
#    with their vt flag (and the icons' compression / mip settings). rune_dot.png -> T_Rune_dot_VT only.
zsh "$repo_root/cook/ue_retry.sh" "$log_dir/import" 15 "RUNIC_OK" 'C:\RunicCook\RunicDecal\RunicDecal.uproject' \
  -run=pythonscript '-script=C:/RunicCook/RunicDecal/create_vt_symbols.py' -nullrhi || exit 1

# 3. Cook + pak as a DLC plugin (Documentation/unreal-project/content-cooking.md of the modkit).
max_attempts=15
for attempt in $(seq 1 $max_attempts); do
  # A crashed attempt can leave a partial cook behind.
  rm -rf "$project_dir/Plugins/Reaper-RunicMarkers/Saved"
  uat_log="$log_dir/uat_try$attempt.log"
  "$wine_bin" --bottle "Epic Games Store" cmd /c "C:\\Program Files\\Epic Games\\UE_5.4\\Engine\\Build\\BatchFiles\\RunUAT.bat" \
    BuildCookRun -project="C:\\RunicCook\\RunicDecal\\RunicDecal.uproject" -noP4 -platform=Win64 -clientconfig=Development \
    -nocompile -nocompileeditor -skipbuild -stage -compress -pak -manifests -dlcname=Reaper-RunicMarkers -cook \
    -unversionedcookedcontent -BasedOnReleaseVersion=1.0 -AdditionalCookerOptions="-AllowUncookedAssetReferences" -unattended > "$uat_log" 2>&1
  if grep -q "BUILD SUCCESSFUL" "$uat_log"; then echo "cook attempt $attempt: OK"; break; fi
  echo "cook attempt $attempt: FAILED (wine assert: $(grep -c 'VPROT_SYSTEM' "$uat_log"))"
  grep -q VPROT_SYSTEM "$uat_log" || { grep -nE "ERROR|Error:" "$uat_log" | head; exit 2; }
  [ "$attempt" = "$max_attempts" ] && exit 1
done

# 4. Install into the mod package.
staged="$project_dir/Plugins/Reaper-RunicMarkers/Saved/StagedBuilds/Windows/RunicDecal/Plugins/Reaper-RunicMarkers/Content/Paks/Windows"
dest="$repo_root/Reaper-RunicMarkers/Content/Paks/Windows"
mkdir -p "$dest"
cp "$staged"/Reaper-RunicMarkerspakchunk0-Windows.* "$dest/"
ls -la "$dest"
