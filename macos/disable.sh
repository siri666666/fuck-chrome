#!/usr/bin/env bash
# Disable and remove Chrome's Gemini Nano on-device model on macOS.
# 1. Policy GenAILocalFoundationalModelSettings = 1 (stops the download)
# 2. Delete OptGuideOnDeviceModel (~4 GB)
set -euo pipefail

POLICY=GenAILocalFoundationalModelSettings
AS="$HOME/Library/Application Support"

echo "[1/2] Chrome policy"
defaults write com.google.Chrome "$POLICY" -int 1
echo "  OK  com.google.Chrome $POLICY = $(defaults read com.google.Chrome "$POLICY")"
if [ -d "$AS/Chromium" ]; then
  defaults write org.chromium.Chromium "$POLICY" -int 1
  echo "  OK  org.chromium.Chromium $POLICY = 1"
fi

echo "[2/2] Model files"
found=0
for d in "$AS/Google/Chrome" "$AS/Google/Chrome Beta" "$AS/Google/Chrome Dev" \
         "$AS/Google/Chrome Canary" "$AS/Chromium"; do
  m="$d/OptGuideOnDeviceModel"
  [ -d "$m" ] || continue
  found=1
  size=$(du -sh "$m" | cut -f1)
  rm -rf "$m"
  echo "  Removed $size  $m"
done
[ "$found" = 1 ] || echo "  No OptGuideOnDeviceModel folder found."

echo
echo "Done. Quit Chrome completely (Cmd+Q) and reopen it, then check chrome://policy."
echo "If $POLICY does not show up there, see the README (configuration profile)."
