#!/bin/sh
# Vendor the canonical amtr engine (fleet feed provider) into the app
# bundle resources. The engine's source of truth lives in the anthropometer
# repo; prefer a sibling checkout, fall back to GitHub raw.
set -e
cd "$(dirname "$0")/.."
DEST=Sources/AmtrBar/Resources/amtr_engine.py
SIBLING="../anthropometer/amtr_engine.py"
if [ -f "$SIBLING" ]; then
  cp "$SIBLING" "$DEST"
  echo "synced engine from sibling anthropometer checkout"
else
  curl -fsSL -o "$DEST" \
    https://raw.githubusercontent.com/arian-shamaei/anthropometer/main/amtr_engine.py
  echo "synced engine from anthropometer@main"
fi
