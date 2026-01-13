//
//  PlayerLayerView.swift
//  Challenge
//
//  Created by Stanley Adigwe on 2026-01-12.
//

import SwiftUI
import AVFoundation
import UIKit

/// SwiftUI wrapper for our custom AVPlayerLayer container
struct PlayerLayerView: UIViewRepresentable {
    let player: AVPlayer
    
    func makeUIView(context: Context) -> PlayerContainerView {
        PlayerContainerView()
    }
    
    func updateUIView(_ uiView: PlayerContainerView, context: Context) {
        uiView.setPlayer(player)
    }
    
    static func dismantleUIView(_ uiView: PlayerContainerView, coordinator: ()) {
        uiView.clearPlayer()
    }
}

/// UIView that hosts AVPlayerLayer with careful readiness handling to prevent black flashes
/// during player/item swaps (very common in infinite scroll / recycled players)
final class PlayerContainerView: UIView {
    
    private let playerLayer = AVPlayerLayer()
    private var readyObs: NSKeyValueObservation?
    
    // Helps detect real player changes vs item swaps in the same player
    private weak var lastPlayer: AVPlayer?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        
        layer.addSublayer(playerLayer)
        playerLayer.videoGravity = .resizeAspectFill
        playerLayer.needsDisplayOnBoundsChange = true
        
        // Start hidden – we only fade in when first frame is ready
        playerLayer.opacity = 0
        armReadyObservation()
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    func setPlayer(_ player: AVPlayer) {
        // Player actually changed (rare in pool, but possible)
        if playerLayer.player !== player {
            playerLayer.player = player
            lastPlayer = player
            playerLayer.opacity = 0
            armReadyObservation()
        }
        // Same player object, but item likely changed (common in our LoopingSlot)
        else {
            armReadyObservation()
            
            // If already ready (fast reuse case), make sure we don't stay hidden
            if playerLayer.isReadyForDisplay {
                playerLayer.opacity = 1
            }
        }
        
        setNeedsLayout()
    }
    
    /// Watches isReadyForDisplay and fades in only when we have actual content
    /// Also hides again if layer loses readiness
    private func armReadyObservation() {
        readyObs?.invalidate()
        readyObs = playerLayer.observe(\.isReadyForDisplay, options: [.initial, .new]) { layer, _ in
            if layer.isReadyForDisplay {
                if layer.opacity < 1 {
                    UIView.animate(withDuration: 0.12) {
                        layer.opacity = 1
                    }
                }
            } else {
                layer.opacity = 0
            }
        }
    }
    
    func clearPlayer() {
        readyObs?.invalidate()
        readyObs = nil
        playerLayer.player = nil
        lastPlayer = nil
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
    }
    
    deinit {
        readyObs?.invalidate()
    }
}
