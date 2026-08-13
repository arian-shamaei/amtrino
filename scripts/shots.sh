#!/bin/sh
# Regenerate README assets from the REAL app (never mockups). Icon frames
# come from the AMTRINO_DUMP hook (exact rendered pixels); window/menu
# shots are screencaptures — run on the display the mouse is on.
#
#   hero-icon.gif  — 28 live frames of the bar icon, 8x nearest-neighbor
#   menu.png       — the open menu (node grid + session table + legend)
#   themes.png     — the gradient theme editor window
#   notification.png — a finished-response banner (needs permission)
#
# Semi-interactive: menu/window shots need the app running and this Mac
# unlocked. Crops assume a Retina main display; adjust offsets if moved.
set -e
echo "1) hero: relaunch with AMTRINO_DUMP=/tmp/hero.png, then:"
echo "   python3 scripts/mkgif.py  (see inline in repo history)"
echo "2) menu: open the status menu, screencapture -x, crop the panel"
echo "3) themes: Options > Theme > Manage themes…, move to main display,"
echo "   screencapture and crop the window bounds from System Events"
echo "4) notification: amtrino --notify-test, crop the banner corner"
echo "(the exact python crops used for v0.1.1 live in the repo history)"
