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
        // Load sounds only when needed to save memory/resources
        soundsInitialized = false
    }
    
    private var soundsInitialized = false
    
    private func initSoundsIfNeeded() {
        // Only initialize sounds if they haven't been initialized
        if soundsInitialized { return }
        
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
            
            soundsInitialized = true
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
        
        // Register for the most reliable volume notification instead of multiple
        center.addObserver(
            self,
            selector: #selector(handleVolumeChange(_:)),
            name: NSNotification.Name("com.apple.sound.settingsChangedNotification"),
            object: nil
        )
        
        // Initialize volume one time at startup
        getSystemVolume { [weak self] initialVolume in
            self?.previousVolume = initialVolume
        }
        
        print("Volume change monitoring set up")
    }
    
    private func getSystemVolume(completion: @escaping (Int) -> Void) {
        DispatchQueue.global(qos: .utility).async {
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
                completion(-1)
                return
            }
            
            DispatchQueue.main.async {
                completion(volume)
            }
        }
    }
    
    // Store the previous volume level and sequence as properties
    private var previousVolume: Int = -1
    private var volumeSequence: [VolumeDirection] = []
    private var sequenceStartTime: Date?
    private var checkTimer: Timer?
    
    @objc private func handleVolumeChange(_ notification: Notification) {
        // Run the volume check on a background thread to avoid blocking the main thread
        getSystemVolume { [weak self] currentVolume in
            guard let self = self, currentVolume != -1 else { return }
            
            // If this is the first time, just initialize the previous volume and return
            if self.previousVolume == -1 {
                self.previousVolume = currentVolume
                return
            }
            
            // Only process if the volume has actually changed
            if currentVolume != self.previousVolume {
                // Determine if volume went up or down
                if currentVolume > self.previousVolume {
                    self.recordVolumeChange(.up)
                } else if currentVolume < self.previousVolume {
                    self.recordVolumeChange(.down)
                }
                
                // Update previous volume
                self.previousVolume = currentVolume
            }
        }
    }
    
    private func recordVolumeChange(_ direction: VolumeDirection) {
        let now = Date()
        
        // If this is the start of a new sequence or the old sequence is expired
        if sequenceStartTime == nil || now.timeIntervalSince(sequenceStartTime!) > 1.5 {
            // Start a new sequence
            volumeSequence = [direction]
            sequenceStartTime = now
            
            // Set a timer to check for pattern completion
            checkTimer?.invalidate()
            checkTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
                self?.checkForVolumePattern()
            }
        } else {
            // Add to existing sequence and check for our target pattern immediately
            volumeSequence.append(direction)
            
            // Check if we have the target pattern now
            if volumeSequence.count == 2 && 
               volumeSequence[0] == .up && 
               volumeSequence[1] == .down {
                
                // Cancel the timer since we're checking now
                checkTimer?.invalidate()
                checkForVolumePattern()
            }
        }
    }
    
    private func checkForVolumePattern() {
        // Check if we have "up" then "down" as the sequence
        if volumeSequence.count == 2 && 
           volumeSequence[0] == .up && 
           volumeSequence[1] == .down {
            
            // Trigger the mic toggle on the main thread
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
        // Initialize sounds if needed
        initSoundsIfNeeded()
        
        // Use system sound if our custom sound isn't available
        if let sound = muteSound, sound.isPlaying == false {
            sound.play()
        } else {
            // Fallback to system sound
            NSSound.beep()
        }
    }
    
    private func playUnmuteSound() {
        // Initialize sounds if needed
        initSoundsIfNeeded()
        
        // Use system sound if our custom sound isn't available
        if let sound = unmuteSound, sound.isPlaying == false {
            sound.play()
        } else {
            // Fallback to system sound
            NSSound.beep()
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
        
        DispatchQueue.global(qos: .userInitiated).async {
            let task = Process()
            task.launchPath = "/usr/bin/osascript"
            task.arguments = ["-e", "set volume input volume \(volume)"]
            task.launch()
            task.waitUntilExit()
        }
    }
    
    @objc private func quitApp() {
        // Clean up
        DistributedNotificationCenter.default().removeObserver(self)
        NSApplication.shared.terminate(nil)
    }
}