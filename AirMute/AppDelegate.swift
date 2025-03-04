import Cocoa
import CoreAudio
import Foundation
import AVFoundation

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var isMuted = false
    private var lastVolumeChangeTime: Date?
    private var lastVolumeDirection: VolumeDirection?
    private var muteSound: AVAudioPlayer?
    private var unmuteSound: AVAudioPlayer?
    
    enum VolumeDirection {
        case up
        case down
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBar()
        setupVolumeChangeMonitoring()
        setupSounds()
        
        // Also keep the keyboard shortcut for testing
        setupKeyboardShortcut()
    }
    
    private func setupSounds() {
        // Use system sounds directly for simplicity
        // Different system sounds for mute and unmute
        
        do {
            // Load mute sound (lower pitch)
            let muteSoundURL = URL(fileURLWithPath: "/System/Library/Sounds/Funk.aiff")
            muteSound = try AVAudioPlayer(contentsOf: muteSoundURL)
            muteSound?.volume = 0.5
            muteSound?.prepareToPlay()
            
            // Load unmute sound (higher pitch)
            let unmuteSoundURL = URL(fileURLWithPath: "/System/Library/Sounds/Glass.aiff")
            unmuteSound = try AVAudioPlayer(contentsOf: unmuteSoundURL)
            unmuteSound?.volume = 0.5
            unmuteSound?.prepareToPlay()
            
            print("Sound system initialized successfully")
        } catch {
            print("Error loading sounds: \(error)")
        }
    }
    
    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "mic", accessibilityDescription: "Microphone")
            
            let menu = NSMenu()
            menu.addItem(NSMenuItem(title: "Toggle Mute", action: #selector(toggleMute), keyEquivalent: "m"))
            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))
            
            statusItem?.menu = menu
        }
        
        updateStatusBarIcon()
    }
    
    private func setupVolumeChangeMonitoring() {
        // Create a distributed notification center to receive volume change notifications
        let center = DistributedNotificationCenter.default()
        
        // Register for multiple volume-related notifications to ensure we catch changes
        let notificationNames = [
            "com.apple.sound.settingsChangedNotification",
            "com.apple.audiocontroller.didchangevolume", 
            "VolumeChanged",
            "SystemVolumeDidChangeNotification"
        ]
        
        for name in notificationNames {
            center.addObserver(
                self,
                selector: #selector(handleVolumeChange(_:)),
                name: NSNotification.Name(name),
                object: nil
            )
        }
        
        // Also use a timer to periodically check the volume
        Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            self?.checkCurrentVolume()
        }
        
        print("Volume change monitoring set up")
    }
    
    private func checkCurrentVolume() {
        // Use AppleScript to get the current volume
        let task = Process()
        let pipe = Pipe()
        
        task.launchPath = "/usr/bin/osascript"
        task.arguments = ["-e", "output volume of (get volume settings)"]
        task.standardOutput = pipe
        
        task.launch()
        task.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let volumeString = String(data: data, encoding: .utf8),
              let volume = Int(volumeString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return
        }
        
        // Only process if the volume has changed
        if volume != previousVolume && previousVolume != -1 {
            // Determine direction
            if volume > previousVolume {
                recordVolumeChange(.up)
                print("Volume UP detected: \(previousVolume) -> \(volume)")
            } else if volume < previousVolume {
                recordVolumeChange(.down)
                print("Volume DOWN detected: \(previousVolume) -> \(volume)")
            }
            previousVolume = volume
        } else if previousVolume == -1 {
            // Initialize the previous volume
            previousVolume = volume
        }
    }
    
    // Store the previous volume level and sequence as properties
    private var previousVolume: Int = -1
    private var volumeSequence: [VolumeDirection] = []
    private var sequenceStartTime: Date?
    private var checkTimer: Timer?
    
    @objc private func handleVolumeChange(_ notification: Notification) {
        // Get the current output volume
        let script = "output volume of (get volume settings)"
        let volumeTask = Process()
        let volumePipe = Pipe()
        
        volumeTask.launchPath = "/usr/bin/osascript"
        volumeTask.arguments = ["-e", script]
        volumeTask.standardOutput = volumePipe
        
        volumeTask.launch()
        volumeTask.waitUntilExit()
        
        let volumeData = volumePipe.fileHandleForReading.readDataToEndOfFile()
        guard let volumeString = String(data: volumeData, encoding: .utf8),
              let currentVolume = Int(volumeString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return
        }
        
        print("Volume change detected: \(currentVolume)")
        
        // If this is the first time, just initialize the previous volume and return
        if previousVolume == -1 {
            previousVolume = currentVolume
            return
        }
        
        // Determine if volume went up or down
        if currentVolume > previousVolume {
            recordVolumeChange(.up)
            print("Volume UP detected")
        } else if currentVolume < previousVolume {
            recordVolumeChange(.down)
            print("Volume DOWN detected")
        }
        
        // Update previous volume
        previousVolume = currentVolume
    }
    
    private func recordVolumeChange(_ direction: VolumeDirection) {
        let now = Date()
        
        // If this is the start of a new sequence or the old sequence is expired
        if sequenceStartTime == nil || now.timeIntervalSince(sequenceStartTime!) > 1.5 {
            // Start a new sequence
            volumeSequence = [direction]
            sequenceStartTime = now
            
            // Set a timer to check after 1 second if pattern is complete
            checkTimer?.invalidate()
            checkTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
                self?.checkForVolumePattern()
            }
            
            print("Started new volume sequence with \(direction)")
        } else {
            // Add to existing sequence
            volumeSequence.append(direction)
            print("Added to sequence: \(volumeSequence)")
            
            // Reset the timer
            checkTimer?.invalidate()
            checkTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
                self?.checkForVolumePattern()
            }
        }
    }
    
    private func checkForVolumePattern() {
        print("Checking pattern: \(volumeSequence)")
        
        // Check if we have "up" then "down" as the sequence
        if volumeSequence.count == 2 && 
           volumeSequence[0] == .up && 
           volumeSequence[1] == .down {
            
            print("✅ UP-DOWN pattern detected! Toggling mic...")
            
            // Trigger the mic toggle
            DispatchQueue.main.async {
                self.toggleMute()
            }
        }
        
        // Reset the sequence
        volumeSequence = []
        sequenceStartTime = nil
    }
    
    
    private func setupKeyboardShortcut() {
        // Register global hotkey for testing (Option+Shift+M)
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.modifierFlags.contains([.option, .shift, .command]) && event.keyCode == 46 { // M key
                DispatchQueue.main.async {
                    self?.toggleMute()
                }
            }
        }
    }
    
    @objc func toggleMute() {
        isMuted.toggle()
        setMicrophoneMute(mute: isMuted)
        updateStatusBarIcon()
        
        // Play appropriate sound
        if isMuted {
            playMuteSound()
        } else {
            playUnmuteSound()
        }
        
        print("Microphone mute toggled - Muted: \(isMuted)")
    }
    
    private func playMuteSound() {
        // Use system sound if our custom sound isn't available
        if let sound = muteSound, sound.isPlaying == false {
            sound.play()
        } else {
            // Fallback to system sound
            NSSound.beep()
        }
    }
    
    private func playUnmuteSound() {
        // Use system sound if our custom sound isn't available
        if let sound = unmuteSound, sound.isPlaying == false {
            sound.play()
        } else {
            // Fallback to system sound with delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NSSound.beep()
            }
        }
    }
    
    private func updateStatusBarIcon() {
        if let button = statusItem?.button {
            let iconName = isMuted ? "mic.slash" : "mic"
            button.image = NSImage(systemSymbolName: iconName, accessibilityDescription: "Microphone")
        }
    }
    
    private func setMicrophoneMute(mute: Bool) {
        // Set input volume using AppleScript for simplicity and reliability
        let volume = mute ? 0 : 20
        let task = Process()
        task.launchPath = "/usr/bin/osascript"
        task.arguments = ["-e", "set volume input volume \(volume)"]
        task.launch()
        task.waitUntilExit()
        
        print("Microphone volume set to \(volume)% - Muted: \(mute)")
    }
    
    @objc private func quitApp() {
        // Clean up
        DistributedNotificationCenter.default().removeObserver(self)
        NSApplication.shared.terminate(nil)
    }
}