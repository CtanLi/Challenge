//
//  FeedViewModel.swift
//  Challenge
//
//  Created by Stanley Adigwe on 2026-01-12.
//

import Foundation
import SwiftUI

/// Top-level view model that owns the video data pipeline:
/// - fetches manifest
/// - manages catalog & player pool
/// - creates & exposes the playback coordinator
@MainActor
final class FeedViewModel: ObservableObject {
    
    private let service: ManifestServicing = ManifestService()
    private let catalog = VideoCatalog()
    private let pool = PlayerPool()
    
    @Published var coordinator: PlaybackCoordinator?
    
    /// One-time initialization: load manifest, set up catalog, create coordinator & start playback
    func load() async {
        AudioSession.configureForPlayback()
        
        do {
            let urls = try await service.fetchManifest()
            catalog.set(urls)
            
            let c = PlaybackCoordinator(catalog: catalog, pool: pool)
            coordinator = c
            c.configureInitial(startIndex: 0)
        } catch {
            print("Manifest load failed:", error)
            // In production → show error UI / retry button
        }
    }
    
    /// Forward typing state to coordinator to pause/resume playback
    func setTyping(_ typing: Bool) {
        coordinator?.pauseForTyping(typing)
    }
}


