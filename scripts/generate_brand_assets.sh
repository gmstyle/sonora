#!/usr/bin/env bash
# Renders the Sonora brand sources (assets/icons/*.svg) into the bitmaps the
# Android tooling consumes. Re-run after editing any of those SVGs.
#
#   scripts/generate_brand_assets.sh
#
# Requirements: ImageMagick with the librsvg delegate (`magick -list format`).
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ICONS="$PROJECT_ROOT/assets/icons"
RES="$PROJECT_ROOT/android/app/src/main/res"

CONVERT_CMD="magick"
command -v "$CONVERT_CMD" >/dev/null 2>&1 || CONVERT_CMD="convert"

render() {
  local src="$1" dst="$2" size="$3"
  "$CONVERT_CMD" -background none -density 384 "$src" -resize "${size}x${size}" \
    -depth 8 -strip "$dst"
  echo "  $dst"
}

echo "Rendering launcher icon sources (flutter_launcher_icons reads these):"
render "$ICONS/icon_legacy.svg" "$ICONS/icon_legacy.png" 1024
render "$ICONS/icon_adaptive_foreground.svg" "$ICONS/icon_adaptive_foreground.png" 1024
render "$ICONS/icon_monochrome.svg" "$ICONS/icon_monochrome.png" 1024

echo "Rendering TV banner:"
mkdir -p "$RES/drawable-xhdpi"
"$CONVERT_CMD" -background "#131429" -density 384 "$ICONS/tv_banner.svg" \
  -resize 320x180! -depth 8 -strip "$RES/drawable-xhdpi/tv_banner.png"
echo "  $RES/drawable-xhdpi/tv_banner.png"

echo "Done. Next: dart run flutter_launcher_icons"
