#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Float Translator
# @raycast.mode silent
# @raycast.packageName AI Tools

# Optional parameters:
# @raycast.icon 🌐

# Documentation:
# @raycast.description Toggle floating translator window
# @raycast.author ruipu

APP_PATH="/Applications/FloatTranslator.app"
BUNDLE_ID="com.floattranslator.app"

# Check if running
if pgrep -f "FloatTranslator.app" > /dev/null; then
    pkill -f "FloatTranslator.app"
    osascript -e 'display notification "Translator closed" with title "FloatTranslator"'
else
    if [ -d "$APP_PATH" ]; then
        open -a "$APP_PATH"
        osascript -e 'display notification "Translator started" with title "FloatTranslator"'
    else
        osascript -e 'display notification "App not found. Run build.sh first." with title "FloatTranslator"'
        exit 1
    fi
fi
