#!/bin/zsh
# Builds the release archive from the COMMITTED mod package: dist/Reaper-RunicMarkers-<modVersion>.zip
# containing a single Reaper-RunicMarkers/ folder (GothicMod.json, Script/, Content/Paks/).
# Usage (from anywhere): zsh tools/package.sh [git-ref]   (default ref: HEAD)
set -eu
repo_root=${0:A:h:h}
ref=${1:-HEAD}
cd "$repo_root"
version=$(git show "$ref:Reaper-RunicMarkers/GothicMod.json" | python3 -c 'import json,sys; print(json.load(sys.stdin)["modVersion"])')
mkdir -p dist
out="dist/Reaper-RunicMarkers-$version.zip"
rm -f "$out"
git archive --format=zip --output="$out" "$ref" Reaper-RunicMarkers
echo "$out"
unzip -l "$out"
