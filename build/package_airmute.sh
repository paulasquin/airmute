#\!/bin/bash

# Script to package AirMute app

# Paths
PROJECT_DIR="."
BUILD_DIR="$PROJECT_DIR/build"
APP_DIR="$BUILD_DIR/AirMute.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

# Remove old build if exists
rm -rf "$APP_DIR"

# Create app structure
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy the icon
cp "$PROJECT_DIR/airmute.png" "$RESOURCES_DIR/"

# Copy Info.plist
cp "$PROJECT_DIR/AirMute/Info.plist" "$CONTENTS_DIR/"

# Create PkgInfo
echo "APPL????" > "$CONTENTS_DIR/PkgInfo"

# Compile the Swift code
echo "Compiling Swift code..."
swiftc -sdk "$(xcrun --show-sdk-path --sdk macosx)" -o "$MACOS_DIR/AirMute" \
    "$PROJECT_DIR/AirMute/AppDelegate.swift" \
    "$PROJECT_DIR/AirMute/main.swift" \
    -framework Cocoa \
    -framework CoreAudio \
    -framework AVFoundation

# Create README
cat > "$BUILD_DIR/AirMute_README.txt" << 'README'
AirMute
=======

This app allows you to quickly toggle your microphone mute state by pressing volume up then volume down within 1 second.

Installation
-----------

1. Open unzip the AirMute.zip file
2. Drag AirMute.app to your Applications folder
3. Launch the app from your Applications folder
4. You may need to right-click the app and select "Open" the first time to bypass Gatekeeper
5. You will see a microphone icon in your menu bar

Usage
-----

1. Press volume up, then quickly press volume down (within 1 second)
2. Wait 1 second for the toggle to activate
3. You'll hear a sound confirming the mic state changed:
   - Low-pitched sound = mic muted (volume set to 0%)
   - High-pitched sound = mic unmuted (volume set to 20%)
4. The menu bar icon also indicates the mic state:
   - Regular mic icon = unmuted
   - Slashed mic icon = muted

Tip: You can also use Option+Shift+M as a keyboard shortcut to toggle the mic.

Auto-Start
----------

To have the app start automatically when you log in:
1. Open System Preferences
2. Go to Users & Groups
3. Select your user account
4. Click on "Login Items"
5. Click the + button
6. Find and select AirMute.app
7. Click "Add"

Enjoy using AirMute\!
README

# Create ZIP archive for distribution
echo "Creating ZIP archive..."
cd "$BUILD_DIR"
zip -r AirMute.zip AirMute.app AirMute_README.txt

echo "Packaging complete\!"
echo "The app is available at: $APP_DIR"
echo "The distribution ZIP is available at: $BUILD_DIR/AirMute.zip"
