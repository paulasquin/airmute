# AirMute

A simple macOS app that toggles the microphone mute state when you quickly change the volume up and down on your AirPods or Mac.

## Features

- Menu bar app with microphone status icon
- Detects when you press volume up then volume down (within 1 second)
- Toggles microphone between muted (0%) and unmuted (20%)
- Different sounds for mute and unmute
- Visual indicator of current mute state in the menu bar
- Also supports keyboard shortcut (Option+Shift+M) for testing

## How to Use

1. Double-click the app to run it (or add to your Login Items for auto-start)
2. Look for a microphone icon in your menu bar
3. To toggle microphone mute/unmute:
   - Press volume up, then press volume down within 1 second
   - Wait 1 second for the toggle to activate
4. You'll hear different sounds for muting and unmuting:
   - Low pitch sound = mic muted
   - High pitch sound = mic unmuted
5. The menu bar icon will also change to indicate the current mute state:
   - Microphone icon = unmuted
   - Slashed microphone icon = muted
6. You can also use Option+Shift+M keyboard shortcut for testing

## Requirements

- macOS 11.1 or later

## Installation

### Option 1: Run the pre-built app
1. Download the latest release from the Releases page
2. Move the app to your Applications folder
3. Double-click to run

### Option 2: Build from source
1. Clone the repository
2. Open AirPodsMicMute.xcodeproj in Xcode
3. Build and run the app

## Tips
- To have the app start automatically when you login, add it to your Login Items in System Preferences > Users & Groups
- If you're using the app with AirPods, ensure they're connected to your Mac
- The app works with the volume buttons on your Mac keyboard as well

## License

This project is available under the MIT License.