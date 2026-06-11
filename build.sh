#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

APP_PATH="/Applications/FloatTranslator.app"
SIGNING_IDENTITY="${FLOAT_TRANSLATOR_SIGNING_IDENTITY:-Apple Development: 1056118649@qq.com (9XZ7S6Q99G)}"
GENERATED_DIR="$SCRIPT_DIR/GeneratedAssets"
ICONSET_DIR="$GENERATED_DIR/AppIcon.iconset"

# Function to generate iOS app icons from logo
generate_ios_icons() {
    local logo_path="$1"
    local output_dir="$2"
    
    echo "📱 Generating iOS app icons..."
    
    # Create temporary directory for processing
    local temp_dir=$(mktemp -d)
    
    # For FloatTranslator logo (1408x768), crop just the icon (blue bubble) without text
    # The speech bubble is roughly at x~454, y~100 with width~500, height~400
    # Use ffmpeg for precise cropping
    
    local icon_size=500
    
    # Crop to the icon region (centered, just the bubble without text)
    # x=454, y=100, w=500, h=400 - then pad to square
    ffmpeg -i "$logo_path" -vf "crop=500:400:454:100,pad=$icon_size:$icon_size:($icon_size-500)/2:($icon_size-400)/2:color=0xFEFBF7@1" -frames:v 1 -y "$temp_dir/logo_square.png" 2>/dev/null
    
    # Generate iPhone sizes
    sips -Z 40 "$temp_dir/logo_square.png" --out "$output_dir/Icon-20@2x.png" >/dev/null 2>&1
    sips -Z 60 "$temp_dir/logo_square.png" --out "$output_dir/Icon-20@3x.png" >/dev/null 2>&1
    sips -Z 58 "$temp_dir/logo_square.png" --out "$output_dir/Icon-29@2x.png" >/dev/null 2>&1
    sips -Z 87 "$temp_dir/logo_square.png" --out "$output_dir/Icon-29@3x.png" >/dev/null 2>&1
    sips -Z 80 "$temp_dir/logo_square.png" --out "$output_dir/Icon-40@2x.png" >/dev/null 2>&1
    sips -Z 120 "$temp_dir/logo_square.png" --out "$output_dir/Icon-40@3x.png" >/dev/null 2>&1
    sips -Z 120 "$temp_dir/logo_square.png" --out "$output_dir/Icon-60@2x.png" >/dev/null 2>&1
    sips -Z 180 "$temp_dir/logo_square.png" --out "$output_dir/Icon-60@3x.png" >/dev/null 2>&1
    
    # Generate iPad sizes
    sips -Z 20 "$temp_dir/logo_square.png" --out "$output_dir/Icon-20.png" >/dev/null 2>&1
    sips -Z 29 "$temp_dir/logo_square.png" --out "$output_dir/Icon-29.png" >/dev/null 2>&1
    sips -Z 40 "$temp_dir/logo_square.png" --out "$output_dir/Icon-40.png" >/dev/null 2>&1
    sips -Z 76 "$temp_dir/logo_square.png" --out "$output_dir/Icon-76.png" >/dev/null 2>&1
    sips -Z 152 "$temp_dir/logo_square.png" --out "$output_dir/Icon-76@2x.png" >/dev/null 2>&1
    sips -Z 167 "$temp_dir/logo_square.png" --out "$output_dir/Icon-83.5@2x.png" >/dev/null 2>&1
    
    # Generate App Store size
    sips -Z 1024 "$temp_dir/logo_square.png" --out "$output_dir/Icon-1024.png" >/dev/null 2>&1
    
    # Clean up temp directory
    rm -rf "$temp_dir"
    
    echo "✅ iOS icons generated in $output_dir"
}

# Function to create Contents.json for AppIcon.appiconset
create_contents_json() {
    local output_dir="$1"
    cat > "$output_dir/Contents.json" << 'JSON'
{
  "images" : [
    {
      "filename" : "Icon-20@2x.png",
      "idiom" : "iphone",
      "scale" : "2x",
      "size" : "20x20"
    },
    {
      "filename" : "Icon-20@3x.png",
      "idiom" : "iphone",
      "scale" : "3x",
      "size" : "20x20"
    },
    {
      "filename" : "Icon-29@2x.png",
      "idiom" : "iphone",
      "scale" : "2x",
      "size" : "29x29"
    },
    {
      "filename" : "Icon-29@3x.png",
      "idiom" : "iphone",
      "scale" : "3x",
      "size" : "29x29"
    },
    {
      "filename" : "Icon-40@2x.png",
      "idiom" : "iphone",
      "scale" : "2x",
      "size" : "40x40"
    },
    {
      "filename" : "Icon-40@3x.png",
      "idiom" : "iphone",
      "scale" : "3x",
      "size" : "40x40"
    },
    {
      "filename" : "Icon-60@2x.png",
      "idiom" : "iphone",
      "scale" : "2x",
      "size" : "60x60"
    },
    {
      "filename" : "Icon-60@3x.png",
      "idiom" : "iphone",
      "scale" : "3x",
      "size" : "60x60"
    },
    {
      "filename" : "Icon-20.png",
      "idiom" : "ipad",
      "scale" : "1x",
      "size" : "20x20"
    },
    {
      "filename" : "Icon-20@2x.png",
      "idiom" : "ipad",
      "scale" : "2x",
      "size" : "20x20"
    },
    {
      "filename" : "Icon-29.png",
      "idiom" : "ipad",
      "scale" : "1x",
      "size" : "29x29"
    },
    {
      "filename" : "Icon-29@2x.png",
      "idiom" : "ipad",
      "scale" : "2x",
      "size" : "29x29"
    },
    {
      "filename" : "Icon-40.png",
      "idiom" : "ipad",
      "scale" : "1x",
      "size" : "40x40"
    },
    {
      "filename" : "Icon-40@2x.png",
      "idiom" : "ipad",
      "scale" : "2x",
      "size" : "40x40"
    },
    {
      "filename" : "Icon-76.png",
      "idiom" : "ipad",
      "scale" : "1x",
      "size" : "76x76"
    },
    {
      "filename" : "Icon-76@2x.png",
      "idiom" : "ipad",
      "scale" : "2x",
      "size" : "76x76"
    },
    {
      "filename" : "Icon-83.5@2x.png",
      "idiom" : "ipad",
      "scale" : "2x",
      "size" : "83.5x83.5"
    },
    {
      "filename" : "Icon-1024.png",
      "idiom" : "ios-marketing",
      "scale" : "1x",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
JSON
}

# Build for iOS (generate assets)
if [ "$1" == "ios" ] || [ "$1" == "ipad" ]; then
    echo "🔨 Building FloatTranslator for iOS..."
    
    # Check for logo file
    LOGO_PATH="${2:-$HOME/Desktop/FloatTranslatorLogo.jpg}"
    if [ ! -f "$LOGO_PATH" ]; then
        echo "❌ Logo not found at $LOGO_PATH"
        echo "Usage: $0 ios [path_to_logo]"
        exit 1
    fi
    
    IOS_ASSETS_DIR="$SCRIPT_DIR/FloatTranslator-iPad/App/Assets.xcassets/AppIcon.appiconset"
    mkdir -p "$IOS_ASSETS_DIR"
    
    # Generate iOS icons
    generate_ios_icons "$LOGO_PATH" "$IOS_ASSETS_DIR"
    
    # Create Contents.json
    create_contents_json "$IOS_ASSETS_DIR"
    
    # Regenerate Xcode project
    cd "$SCRIPT_DIR/FloatTranslator-iPad"
    xcodegen generate
    
    echo "✅ iOS assets generated. Open FloatTranslator-iPad.xcodeproj in Xcode to build."
    exit 0
fi

# Default: Build for macOS
echo "🔨 Building FloatTranslator for macOS..."

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
