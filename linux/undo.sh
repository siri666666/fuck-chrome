#!/usr/bin/env bash
# Undo linux/disable.sh
set -uo pipefail
FILE=disable-on-device-model.json
for d in /etc/opt/chrome/policies/managed /etc/chromium/policies/managed /etc/chromium-browser/policies/managed; do
  [ -f "$d/$FILE" ] && sudo rm -f "$d/$FILE" && echo "Removed $d/$FILE"
done
echo "Restart Chrome for it to take effect."
