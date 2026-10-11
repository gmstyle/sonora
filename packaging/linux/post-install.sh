#!/bin/sh
set -e

if command -v gtk-update-icon-cache &>/dev/null; then
  gtk-update-icon-cache -f -q /usr/share/icons/hicolor/ 2>/dev/null || true
fi

if command -v update-desktop-database &>/dev/null; then
  update-desktop-database -q 2>/dev/null || true
fi

# Register sonora:// so xdg-open / browsers can hand links to Sonora.
if command -v xdg-mime &>/dev/null; then
  xdg-mime default com.gmstyle.sonora.desktop x-scheme-handler/sonora 2>/dev/null || true
fi
