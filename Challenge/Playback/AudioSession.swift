//
//  AudioSession.swift
//  Challenge
//
//  Created by Stanley Adigwe on 2026-01-12.
//

import AVFoundation

/// Simple helper for setting up AVAudioSession correctly for video playback
enum AudioSession {
    
    /// Configures the shared audio session for background-capable video/movie playback
    static func configureForPlayback() {
        let session = AVAudioSession.sharedInstance()
        
        do {
            // .playback + .moviePlayback gives us background audio + proper ducking/mixing
            try session.setCategory(.playback, mode: .moviePlayback, options: [])
            try session.setActive(true)
        } catch {
            print("AudioSession configure failed:", error)
        }
    }
}

