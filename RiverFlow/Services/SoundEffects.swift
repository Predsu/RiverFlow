import AppKit

/// Collection of utilities for playing app's sound effects.
struct SoundEffects {
    /// Warms audio engine by playing silent system sound.
    /// - Warning: It helps only for the first few minutes of app running. Issue fixing ongoing.
    static func warmUpAudioEngine() {
        if let silentSound = NSSound(named: "Tink") {
            silentSound.volume = 0.0
            silentSound.play()
        }
    }
    
    /// Plays custom sound effect.
    /// - Parameter name: Name of the sound asset (without file extension).
    /// - Note: Playback may be latenced or corrupted if audio engine not warmed up. See: `warmUpAudioEngine` method.
    static func playSoundEffect(name: String) {
        if let sound = NSSound(named: name) {
            sound.play()
        }
    }
}
