#!/usr/bin/env bash
set -euo pipefail

# ─── Config ──────────────────────────────────────────────────────────────────
APP_NAME="sonora"
APP_ID="com.gmstyle.sonora"
DESCRIPTION="A music streaming app powered by YouTube Music"
LICENSE="MIT"
VENDOR="Gabriele Martina"
MAINTAINER="Gabriele Martina <gabriele.martina@example.com>"
HOMEPAGE="https://github.com/gmstyle/sonora"

# ─── RPM / DEB dependencies ─────────────────────────────────────────────────
DEB_DEPENDS="libgtk-3-0, libayatana-appindicator3-1, libmpv2"
RPM_DEPENDS="gtk3, libappindicator-gtk3, mpv-libs"

# ─── Paths ────────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BUNDLE_DIR="$PROJECT_ROOT/build/linux/x64/release/bundle"
OUTPUT_DIR="$PROJECT_ROOT/build/packages"

# ─── Parse arguments ──────────────────────────────────────────────────────────
FORMAT=""
SKIP_BUILD=false

usage() {
  echo "Usage: $0 --format deb|rpm|all [--skip-build]"
  echo ""
  echo "Options:"
  echo "  --format      Package format to build (deb, rpm, all)"
  echo "  --skip-build  Skip 'flutter build linux --release' if bundle already exists"
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --format)    FORMAT="$2"; shift 2 ;;
    --skip-build) SKIP_BUILD=true; shift ;;
    --help|-h)   usage ;;
    *)           echo "Unknown option: $1"; usage ;;
  esac
done

if [[ -z "$FORMAT" ]]; then
  echo "ERROR: --format is required"
  usage
fi

# ─── Version from pubspec.yaml ────────────────────────────────────────────────
VERSION=$(grep '^version:' "$PROJECT_ROOT/pubspec.yaml" | awk '{print $2}')
APP_VERSION=$(echo "$VERSION" | cut -d'+' -f1)
BUILD_NUMBER=$(echo "$VERSION" | cut -d'+' -f2)

echo "==> $APP_NAME v$APP_VERSION (build $BUILD_NUMBER)"
echo ""

# ─── Dependency checks ────────────────────────────────────────────────────────
if [[ "$FORMAT" == "deb" || "$FORMAT" == "rpm" || "$FORMAT" == "all" ]]; then
  if ! command -v fpm &>/dev/null; then
    echo "ERROR: 'fpm' not found. Install it:"
    echo "  sudo gem install fpm"
    echo "  # or on Fedora: sudo dnf copr enable ngompa/fpm && sudo dnf install fpm"
    exit 1
  fi
fi

# ─── Flutter build ────────────────────────────────────────────────────────────
if [[ "$SKIP_BUILD" == false ]]; then
  echo "==> Flutter build linux --release..."
  (cd "$PROJECT_ROOT" && flutter build linux --release)
  echo ""
elif [[ ! -d "$BUNDLE_DIR" ]]; then
  echo "ERROR: Bundle not found at $BUNDLE_DIR"
  echo "  Run 'flutter build linux --release' first or omit --skip-build"
  exit 1
fi

# ─── Prepare staging directory ────────────────────────────────────────────────
STAGING_DIR=$(mktemp -d)
trap 'rm -rf "$STAGING_DIR"' EXIT

echo "==> Preparing staging directory..."

mkdir -p "$STAGING_DIR/opt/$APP_NAME"
cp -r "$BUNDLE_DIR"/* "$STAGING_DIR/opt/$APP_NAME/"

# App icon
cp "$PROJECT_ROOT/assets/logo_full.png" "$STAGING_DIR/opt/$APP_NAME/sonora.png"

# Tray icon (downscale to 48x48 for system tray compatibility)
cp "$PROJECT_ROOT/assets/icons/tray/tray_icon.png" "$STAGING_DIR/opt/$APP_NAME/tray_icon.png"
if command -v convert &>/dev/null; then
  convert "$STAGING_DIR/opt/$APP_NAME/tray_icon.png" \
    -resize 48x48 "$STAGING_DIR/opt/$APP_NAME/tray_icon.png"
fi

# Symlink in PATH
mkdir -p "$STAGING_DIR/usr/bin"
ln -s "/opt/$APP_NAME/$APP_NAME" "$STAGING_DIR/usr/bin/$APP_NAME"

# Desktop entry (system-wide path)
mkdir -p "$STAGING_DIR/usr/share/applications"
cat > "$STAGING_DIR/usr/share/applications/$APP_ID.desktop" << DESKTOP_EOF
[Desktop Entry]
Name=Sonora
Comment=$DESCRIPTION
Exec=/opt/$APP_NAME/sonora
Icon=/opt/$APP_NAME/sonora.png
Terminal=false
Type=Application
Categories=Audio;Music;Player;
StartupWMClass=$APP_ID
DESKTOP_EOF

# Launcher icons — SVG (scalable) + PNG fallbacks at multiple sizes
mkdir -p "$STAGING_DIR/usr/share/icons/hicolor/scalable/apps"
cp "$PROJECT_ROOT/assets/logo_full.svg" \
  "$STAGING_DIR/usr/share/icons/hicolor/scalable/apps/sonora.svg"

for SIZE in 48 64 128 256; do
  mkdir -p "$STAGING_DIR/usr/share/icons/hicolor/${SIZE}x${SIZE}/apps"
  if command -v convert &>/dev/null; then
    convert "$PROJECT_ROOT/assets/logo_full.png" \
      -resize "${SIZE}x${SIZE}" \
      "$STAGING_DIR/usr/share/icons/hicolor/${SIZE}x${SIZE}/apps/sonora.png"
  else
    cp "$PROJECT_ROOT/assets/logo_full.png" \
      "$STAGING_DIR/usr/share/icons/hicolor/${SIZE}x${SIZE}/apps/sonora.png"
  fi
done

mkdir -p "$OUTPUT_DIR"

# ─── Build DEB ────────────────────────────────────────────────────────────────
if [[ "$FORMAT" == "deb" || "$FORMAT" == "all" ]]; then
  echo "==> Building DEB package..."

  fpm -s dir -t deb \
    --name "$APP_NAME" \
    --version "$APP_VERSION" \
    --iteration "$BUILD_NUMBER" \
    --license "$LICENSE" \
    --vendor "$VENDOR" \
    --maintainer "$MAINTAINER" \
    --description "$DESCRIPTION" \
    --url "$HOMEPAGE" \
    --category "audio" \
    --depends libgtk-3-0 \
    --depends libayatana-appindicator3-1 \
    --depends libmpv2 \
    --after-install "$SCRIPT_DIR/post-install.sh" \
    -C "$STAGING_DIR" \
    --package "$OUTPUT_DIR" \
    --force \
    .

  echo "  -> DEB: $(ls "$OUTPUT_DIR"/*.deb 2>/dev/null)"
  echo ""
fi

# ─── Build RPM ────────────────────────────────────────────────────────────────
if [[ "$FORMAT" == "rpm" || "$FORMAT" == "all" ]]; then
  echo "==> Building RPM package..."

  fpm -s dir -t rpm \
    --name "$APP_NAME" \
    --version "$APP_VERSION" \
    --iteration "$BUILD_NUMBER" \
    --license "$LICENSE" \
    --vendor "$VENDOR" \
    --maintainer "$MAINTAINER" \
    --description "$DESCRIPTION" \
    --url "$HOMEPAGE" \
    --category "Applications/Multimedia" \
    --depends "gtk3" \
    --depends "libappindicator-gtk3" \
    --depends "mpv-libs" \
    --after-install "$SCRIPT_DIR/post-install.sh" \
    -C "$STAGING_DIR" \
    --package "$OUTPUT_DIR" \
    --force \
    .

  echo "  -> RPM: $(ls "$OUTPUT_DIR"/*.rpm 2>/dev/null)"
  echo ""
fi

# ─── Done ─────────────────────────────────────────────────────────────────────
echo "================================================"
echo "Packages created in: $OUTPUT_DIR"
echo ""
ls -lh "$OUTPUT_DIR" 2>/dev/null | grep -v '/$' || true
