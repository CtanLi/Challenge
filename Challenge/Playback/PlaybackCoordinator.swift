//
//  PlaybackCoordinator.swift
//  Challenge
//
//  Created by Stanley Adigwe on 2026-01-12.
//

import Foundation
import AVFoundation

/// Coordinates video playback across a 3-slot pool (prev/current/next) with infinite scrolling,
/// readiness gating, typing pause, and safe preroll to minimize stalls/black frames
@MainActor
final class PlaybackCoordinator: ObservableObject {
    
    @Published private(set) var currentIndex: Int = 0
    @Published var isTyping: Bool = false
    @Published var showLoadingGate: Bool = false
    
    private let catalog: VideoCatalog
    private let pool: PlayerPool
    
    init(catalog: VideoCatalog, pool: PlayerPool) {
        self.catalog = catalog
        self.pool = pool
    }
    
    func configureInitial(startIndex: Int = 0) {
        currentIndex = startIndex
        
        let curr = catalog.model(at: currentIndex).url
        let next = catalog.model(at: currentIndex + 1).url
        let prev = catalog.model(at: currentIndex - 1).url
        
        pool.slot(.current).set(url: curr)
        pool.slot(.next).set(url: next)
        pool.slot(.prev).set(url: prev)
        
        pool.slot(.current).play()
        warmUp(.next)
    }
    
    func pauseForTyping(_ typing: Bool) {
        isTyping = typing
        if typing {
            pool.slot(.current).pause()
        } else {
            pool.slot(.current).play()
        }
    }
    
    func prevPlayer() -> AVPlayer { pool.slot(.prev).player }
    func currentPlayer() -> AVPlayer { pool.slot(.current).player }
    func nextPlayer() -> AVPlayer { pool.slot(.next).player }
    
    /// Gate that prevents page advance until target slot is sufficiently ready
    func gateAdvance(direction: Int) async -> Bool {
        guard !isTyping else { return false }
        guard direction != 0 else { return true }
        
        showLoadingGate = true
        defer { showLoadingGate = false }
        
        if direction > 0 {
            return await waitUntilReady(slot: .next, timeout: 8.0)
        } else {
            return await waitUntilReady(slot: .prev, timeout: 8.0)
        }
    }
    
    /// Finalizes index update and pool rotation after successful gate
    func commitAdvance(direction: Int) {
        guard direction != 0 else { return }
        
        if direction > 0 {
            currentIndex += 1
            pool.rotateForward()
            
            let newNext = catalog.model(at: currentIndex + 1).url
            pool.slot(.next).set(url: newNext)
        } else {
            currentIndex -= 1
            pool.rotateBackward()
            
            let newPrev = catalog.model(at: currentIndex - 1).url
            pool.slot(.prev).set(url: newPrev)
        }
        
        pool.slot(.current).play()
        warmUp(.next)
    }
    
    // MARK: - Preroll & Readiness Helpers
    
    private func warmUp(_ kind: PlayerPool.Kind) {
        Task { @MainActor in
            let slot = pool.slot(kind)
            guard await waitUntilReady(slot: kind, timeout: 5.0) else { return }
            guard slot.player.status == .readyToPlay else { return }
            
            slot.player.preroll(atRate: 1.0) { _ in }
        }
    }
    
    /// Waits for strong readiness signals (item + player + ideally buffering)
    private func waitUntilReady(slot kind: PlayerPool.Kind, timeout: TimeInterval) async -> Bool {
        let slot = pool.slot(kind)
        let player = slot.player
        
        guard let item = slot.currentItem else { return true }
        
        let start = Date()
        while Date().timeIntervalSince(start) < timeout {
            try? await Task.sleep(nanoseconds: 150_000_000) // ~150ms polling
            
            if item.status == .failed { return false }
            
            let itemReady = item.status == .readyToPlay
            let playerReady = player.status == .readyToPlay
            let keepUp = item.isPlaybackLikelyToKeepUp
            
            // Best case: fully buffered and ready
            if itemReady && playerReady && keepUp { return true }
            // Acceptable: at least both readyToPlay (still prevents most black frames)
            if itemReady && playerReady { return true }
        }
        
        // Fallback: allow if minimally ready (better than blocking forever)
        return item.status == .readyToPlay && player.status == .readyToPlay
    }
}
