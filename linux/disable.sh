#!/usr/bin/env bash
# Disable and remove Chrome's Gemini Nano on-device model on Linux.
# Run as your normal user (not with sudo); it calls sudo only to write the policy file.
set -euo pipefail

POLICY=GenAILocalFoundationalModelSettings
FILE=disable-on-device-model.json
JSON="{ \"$POLICY\": 1 }"

if [ "$(id -u)" = 0 ]; then
  echo "Run this as your normal user, not root (it needs your \$HOME to find the model)." >&2
  exit 1
fi

echo "[1/2] Chrome policy"
dirs=(/etc/opt/chrome/policies/managed)
[ -d "$HOME/.config/chromium" ] && dirs+=(/etc/chromium/policies/managed /etc/chromium-browser/policies/managed)
for d in "${dirs[@]}"; do
  sudo mkdir -p "$d"
  echo "$JSON" | sudo tee "$d/$FILE" >/dev/null
  echo "  OK  $d/$FILE"
done

echo "[2/2] Model files"
found=0
for d in "$HOME/.config/google-chrome" "$HOME/.config/google-chrome-beta" \
         "$HOME/.config/google-chrome-unstable" "$HOME/.config/chromium"; do
  m="$d/OptGuideOnDeviceModel"
  [ -d "$m" ] || continue
  found=1
  size=$(du -sh "$m" | cut -f1)
  rm -rf "$m"
  echo "  Removed $size  $m"
done
[ "$found" = 1 ] || echo "  No OptGuideOnDeviceModel folder found."

echo
echo "Done. Restart Chrome (chrome://restart), then check chrome://policy."
