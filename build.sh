#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

APP_PATH="/Applications/FloatTranslator.app"
SIGNING_IDENTITY="${FLOAT_TRANSLATOR_SIGNING_IDENTITY:-Apple Development: 1056118649@qq.com (9XZ7S6Q99G)}"
GENERATED_DIR="$SCRIPT_DIR/GeneratedAssets"
ICONSET_DIR="$GENERATED_DIR/AppIcon.iconset"

echo "🔨 Building FloatTranslator..."

swift Scripts/generate_assets.swift "$GENERATED_DIR"

rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"

sips -z 16 16 "$GENERATED_DIR/AppIcon-1024.png" --out "$ICONSET_DIR/icon_16x16.png" >/dev/null
sips -z 32 32 "$GENERATED_DIR/AppIcon-1024.png" --out "$ICONSET_DIR/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$GENERATED_DIR/AppIcon-1024.png" --out "$ICONSET_DIR/icon_32x32.png" >/dev/null
sips -z 64 64 "$GENERATED_DIR/AppIcon-1024.png" --out "$ICONSET_DIR/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$GENERATED_DIR/AppIcon-1024.png" --out "$ICONSET_DIR/icon_128x128.png" >/dev/null
sips -z 256 256 "$GENERATED_DIR/AppIcon-1024.png" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$GENERATED_DIR/AppIcon-1024.png" --out "$ICONSET_DIR/icon_256x256.png" >/dev/null
sips -z 512 512 "$GENERATED_DIR/AppIcon-1024.png" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$GENERATED_DIR/AppIcon-1024.png" --out "$ICONSET_DIR/icon_512x512.png" >/dev/null
cp "$GENERATED_DIR/AppIcon-1024.png" "$ICONSET_DIR/icon_512x512@2x.png"

iconutil -c icns "$ICONSET_DIR" -o "$GENERATED_DIR/AppIcon.icns"

# Compile Swift source
swiftc -o FloatTranslator Sources/main.swift \
  -framework Cocoa \
  -framework SwiftUI \
  -framework ApplicationServices \
  -framework ScreenCaptureKit \
  -framework Vision \
  -O

# Remove old app from Applications
rm -rf "$APP_PATH"

# Create app bundle directly in Applications
mkdir -p "$APP_PATH/Contents/MacOS"
mkdir -p "$APP_PATH/Contents/Resources"
mv FloatTranslator "$APP_PATH/Contents/MacOS/"
cp "$GENERATED_DIR/AppIcon.icns" "$APP_PATH/Contents/Resources/"
cp "$GENERATED_DIR/StatusBarIconTemplate.png" "$APP_PATH/Contents/Resources/"

# Create Info.plist
cat > "$APP_PATH/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>FloatTranslator</string>
    <key>CFBundleIdentifier</key>
    <string>com.floattranslator.app</string>
    <key>CFBundleName</key>
    <string>FloatTranslator</string>
    <key>CFBundleDisplayName</key>
    <string>FloatTranslator</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
PLIST

codesign --force --deep --sign "$SIGNING_IDENTITY" "$APP_PATH"

echo "✅ Installed and signed: $APP_PATH"
