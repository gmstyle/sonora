#!/usr/bin/env bash
set -euo pipefail

APP=sonora
REPO=https://github.com/gmstyle/sonora.git
BRANCH=main
INSTALL_DIR="${SONORA_DIR:-$HOME/.sonora/cli}"
BIN_DIR="$HOME/.local/bin"
WRAPPER="$BIN_DIR/sonora"
WRAPPER_NAME="sonora"

MUTED='\033[0;2m'
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${MUTED}Sonora CLI Installer${NC}"
echo ""

# ── Prerequisites ──────────────────────────────────────────────────

if ! command -v git >/dev/null 2>&1; then
  echo -e "${RED}Error: git is required but not installed.${NC}"
  exit 1
fi

if ! command -v flutter >/dev/null 2>&1; then
  echo -e "${RED}Error: Flutter SDK is required but not installed.${NC}"
  echo -e "${MUTED}Install Flutter: https://docs.flutter.dev/get-started/install${NC}"
  exit 1
fi

flutter_version=$(flutter --version 2>&1 | head -1)
echo -e "${MUTED}Found:${NC} $flutter_version"
echo ""

# ── Clone / Update ─────────────────────────────────────────────────

if [ -d "$INSTALL_DIR/.git" ]; then
  echo -e "${MUTED}Updating existing installation in${NC} $INSTALL_DIR"
  cd "$INSTALL_DIR"
  git pull
elif [ -d "$INSTALL_DIR" ]; then
  echo -e "${MUTED}Replacing stale directory...${NC}"
  rm -rf "$INSTALL_DIR"
  echo -e "${MUTED}Cloning into${NC} $INSTALL_DIR"
  git clone --depth 1 --branch "$BRANCH" "$REPO" "$INSTALL_DIR"
  cd "$INSTALL_DIR"
else
  echo -e "${MUTED}Cloning into${NC} $INSTALL_DIR"
  git clone --depth 1 --branch "$BRANCH" "$REPO" "$INSTALL_DIR"
  cd "$INSTALL_DIR"
fi

echo ""

# ── Setup ──────────────────────────────────────────────────────────

echo -e "${MUTED}Installing Dart dependencies...${NC}"
flutter pub get
echo ""

echo -e "${MUTED}Generating Drift code...${NC}"
dart run build_runner build --delete-conflicting-outputs 2>&1 | tail -1 || true
echo ""

# ── Create wrapper script ──────────────────────────────────────────

mkdir -p "$BIN_DIR"

cat > "$WRAPPER" <<WRAPPER
#!/usr/bin/env bash
exec dart run $INSTALL_DIR/bin/sonora.dart "\$@"
WRAPPER

chmod +x "$WRAPPER"
echo -e "${MUTED}Created wrapper at${NC} $WRAPPER"
echo ""

# ── PATH setup ─────────────────────────────────────────────────────

add_to_path() {
  local config_file=$1
  local line="export PATH=\"\$PATH:$BIN_DIR\""

  if [ ! -f "$config_file" ]; then
    return
  fi

  if grep -qF "$BIN_DIR" "$config_file" 2>/dev/null; then
    return
  fi

  if grep -qF "$WRAPPER_NAME" "$config_file" 2>/dev/null; then
    return
  fi

  {
    echo ""
    echo "# Sonora CLI"
    echo "$line"
  } >> "$config_file"
  echo -e "${MUTED}Added $BIN_DIR to PATH in${NC} $config_file"
}

current_shell=$(basename "$SHELL")
case $current_shell in
  zsh)
    for f in "${ZDOTDIR:-$HOME}/.zshrc" "$HOME/.zshenv"; do
      [ -f "$f" ] && add_to_path "$f"
    done
    ;;
  bash)
    for f in "$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.profile"; do
      [ -f "$f" ] && add_to_path "$f"
    done
    ;;
  fish)
    add_to_path "$HOME/.config/fish/config.fish"
    ;;
esac

echo ""

# ── Verify ─────────────────────────────────────────────────────────

echo -e "${MUTED}Verifying installation...${NC}"

if [ -x "$WRAPPER" ]; then
  "$WRAPPER" --help
else
  echo -e "${RED}Wrapper not found at $WRAPPER.${NC}"
  echo -e "${MUTED}Try running directly:${NC} dart run $INSTALL_DIR/bin/sonora.dart --help"
fi

echo ""
echo -e "${GREEN}Sonora CLI installed successfully!${NC}"
echo ""
echo -e "${MUTED}Usage:${NC} sonora <command> [options]"
echo -e "${MUTED}Help:${NC}  sonora --help"
echo ""
echo -e "${MUTED}Update:${NC} curl -fsSL https://raw.githubusercontent.com/gmstyle/sonora/$BRANCH/install.sh | bash"
echo -e "${MUTED}Uninstall:${NC} rm -f $WRAPPER && rm -rf $INSTALL_DIR"
echo ""
