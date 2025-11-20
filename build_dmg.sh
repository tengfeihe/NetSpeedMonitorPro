#!/bin/bash

# ---------------- Configuration ----------------
APP_NAME="NetSpeedMonitorPro"
SWIFT_FILE="NetSpeedMonitorPro.swift"
DMG_FINAL="${APP_NAME}.dmg"
DMG_TEMP="temp.dmg"
APP_BUNDLE="${APP_NAME}.app"
ICON_SOURCE="icon.png"
STAGING_DIR="dmg_staging"
# -----------------------------------------------

# 0. [NEW] Force close running instance of the old app
echo "🛑 Checking and closing running instances..."
pkill -x "$APP_NAME"
# Wait for process to exit completely
sleep 1

# 1. Check source file
if [ ! -f "$SWIFT_FILE" ]; then
    echo "❌ Error: $SWIFT_FILE not found"
    exit 1
fi

echo "🚀 Starting build for $APP_NAME..."

# 2. Clean up old files
rm -rf "$APP_BUNDLE" "$DMG_FINAL" "$DMG_TEMP" "$STAGING_DIR" "MyIcon.iconset"

# 3. Create .app bundle structure
echo "📂 Creating app bundle structure..."
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# 4. Process Icon (if exists)
if [ -f "$ICON_SOURCE" ]; then
    echo "🎨 Generating App Icon (Forcing PNG format)..."
    mkdir MyIcon.iconset
    
    # Fix: Explicitly add --setProperty format png to prevent sips errors
    sips -z 16 16     "$ICON_SOURCE" --setProperty format png --out MyIcon.iconset/icon_16x16.png > /dev/null
    sips -z 32 32     "$ICON_SOURCE" --setProperty format png --out MyIcon.iconset/icon_16x16@2x.png > /dev/null
    sips -z 32 32     "$ICON_SOURCE" --setProperty format png --out MyIcon.iconset/icon_32x32.png > /dev/null
    sips -z 64 64     "$ICON_SOURCE" --setProperty format png --out MyIcon.iconset/icon_32x32@2x.png > /dev/null
    sips -z 128 128   "$ICON_SOURCE" --setProperty format png --out MyIcon.iconset/icon_128x128.png > /dev/null
    sips -z 256 256   "$ICON_SOURCE" --setProperty format png --out MyIcon.iconset/icon_128x128@2x.png > /dev/null
    sips -z 256 256   "$ICON_SOURCE" --setProperty format png --out MyIcon.iconset/icon_256x256.png > /dev/null
    sips -z 512 512   "$ICON_SOURCE" --setProperty format png --out MyIcon.iconset/icon_512x512@2x.png > /dev/null
    sips -z 512 512   "$ICON_SOURCE" --setProperty format png --out MyIcon.iconset/icon_512x512.png > /dev/null
    sips -z 1024 1024 "$ICON_SOURCE" --setProperty format png --out MyIcon.iconset/icon_512x512@2x.png > /dev/null
    
    # Package
    echo "📦 Packaging icns file..."
    iconutil -c icns MyIcon.iconset
    
    if [ -f "MyIcon.icns" ]; then
        mv MyIcon.icns "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
        echo "✅ Icon generated successfully!"
    else
        echo "⚠️ Icon generation failed, using default icon."
    fi
    
    rm -rf MyIcon.iconset
else
    echo "⚠️ icon.png not found, skipping icon generation."
fi

# 5. Compile Swift code
echo "🔨 Compiling code..."
swiftc "$SWIFT_FILE" -o "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
if [ $? -ne 0 ]; then echo "❌ Compilation failed"; exit 1; fi

# 6. Generate Info.plist
echo "📝 Generating configuration file..."
cat > "$APP_BUNDLE/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.local.$APP_NAME</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

# 7. Prepare DMG content
echo "📦 Preparing DMG content..."
mkdir -p "$STAGING_DIR"
cp -r "$APP_BUNDLE" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

# 8. Create temporary DMG
echo "💿 Creating temporary disk image..."
hdiutil create -srcfolder "$STAGING_DIR" -volname "$APP_NAME" -fs HFS+ -fsargs "-c c=64,a=16,e=16" -format UDRW "$DMG_TEMP" > /dev/null

# 9. Mount and Layout (AppleScript)
echo "📐 Adjusting icon layout (this may take a few seconds)..."
DEVICE=$(hdiutil attach -readwrite -noverify -noautoopen "$DMG_TEMP" | egrep '^/dev/' | sed 1q | awk '{print $1}')
sleep 2

echo '
tell application "Finder"
    tell disk "'$APP_NAME'"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {400, 100, 900, 450}
        set theViewOptions to the icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 128
        set position of item "'$APP_NAME'.app" of container window to {140, 150}
        set position of item "Applications" of container window to {360, 150}
        close
        open
        update without registering applications
        delay 2
    end tell
end tell
' | osascript

sync
echo "⏏️  Detaching temporary image..."
hdiutil detach "$DEVICE" > /dev/null

# 10. Convert to final DMG
echo "🎁 Generating final DMG..."
hdiutil convert "$DMG_TEMP" -format UDZO -imagekey zlib-level=9 -o "$DMG_FINAL" > /dev/null

rm -rf "$DMG_TEMP" "$STAGING_DIR" "$APP_BUNDLE"

echo "✅ All done!"
echo "Generated file: $(pwd)/$DMG_FINAL"