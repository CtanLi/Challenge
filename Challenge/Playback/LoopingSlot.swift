//
//  LoopingSlot.swift
//  Challenge
//
//  Created by Stanley Adigwe on 2026-01-12.
//

import AVFoundation

/// Manages a single infinitely looping video player slot using AVQueuePlayer + AVPlayerLooper
final class LoopingSlot {
    
    let player: AVQueuePlayer
    private var looper: AVPlayerLooper?
    private(set) var currentURL: URL?
    
    init() {
        self.player = AVQueuePlayer()
        self.player.actionAtItemEnd = .none
        self.player.isMuted = true
        self.player.automaticallyWaitsToMinimizeStalling = true
    }
    
    var currentItem: AVPlayerItem? { player.currentItem }
    
    /// Replaces the current looping video only if the URL actually changed
    func set(url: URL) {
        guard currentURL != url else { return }
        currentURL = url
        
        looper = nil
        player.removeAllItems()
        
        let asset = AVURLAsset(url: url)
        let item = AVPlayerItem(asset: asset)
        
        // Small forward buffer + unlimited peak bit rate → faster startup, smoother looping
        item.preferredForwardBufferDuration = 0.5
        item.preferredPeakBitRate = 0
        
        looper = AVPlayerLooper(player: player, templateItem: item)
    }
    
    func play() { player.play() }
    func pause() { player.pause() }
}
