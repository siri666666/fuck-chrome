#!/usr/bin/env bash
# Undo macos/disable.sh
set -uo pipefail
POLICY=GenAILocalFoundationalModelSettings
defaults delete com.google.Chrome "$POLICY" 2>/dev/null && echo "Removed com.google.Chrome $POLICY"
defaults delete org.chromium.Chromium "$POLICY" 2>/dev/null && echo "Removed org.chromium.Chromium $POLICY"
echo "Restart Chrome for it to take effect."
