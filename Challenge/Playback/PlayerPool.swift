//
//  PlayerPool.swift
//  Challenge
//
//  Created by Stanley Adigwe on 2026-01-12.
//

import Foundation

/// Manages a fixed pool of 3 looping video players: previous, current, and next.
/// Handles rotation when the user swipes to keep the active player always in the middle slot.
final class PlayerPool {
    
    enum Kind { case prev, current, next }
    
    private let prev = LoopingSlot()
    private let current = LoopingSlot()
    private let next = LoopingSlot()
    
    func slot(_ kind: Kind) -> LoopingSlot {
        switch kind {
        case .prev:    return prev
        case .current: return current
        case .next:    return next
        }
    }
    
    /// Shifts everything forward after user moves to the next video:
    ///   old current → becomes new prev
    ///   old next    → becomes new current
    ///   new next    will be loaded separately by the coordinator
    func rotateForward() {
        let oldCurrentURL = current.currentURL
        let oldNextURL = next.currentURL
        
        if let oldCurrentURL { prev.set(url: oldCurrentURL) }
        if let oldNextURL    { current.set(url: oldNextURL) }
    }
    
    /// Shifts everything backward after user moves to the previous video:
    ///   old current → becomes new next
    ///   old prev    → becomes new current
    ///   new prev    will be loaded separately by the coordinator
    func rotateBackward() {
        let oldCurrentURL = current.currentURL
        let oldPrevURL = prev.currentURL
        
        if let oldCurrentURL { next.set(url: oldCurrentURL) }
        if let oldPrevURL    { current.set(url: oldPrevURL) }
    }
}

