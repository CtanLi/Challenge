//
//  ManifestService.swift
//  Challenge
//
//  Created by Stanley Adigwe on 2026-01-12.
//

import Foundation

/// Handles fetching the list of video URLs from the remote manifest
protocol ManifestServicing {
    func fetchManifest() async throws -> [URL]
}

final class ManifestService: ManifestServicing {
    
    // CDN manifest location
    private let manifestURL = URL(string: "https://cdn.dev.airxp.app/AgentVideos-HLS-Progressive/manifest.json")!
    
    func fetchManifest() async throws -> [URL] {
        // Fetch raw manifest data
        let (data, response) = try await URLSession.shared.data(from: manifestURL)
        
        // Verify successful HTTP response
        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        // Parse manifest and extract video URLs
        let manifest = try JSONDecoder().decode(Manifest.self, from: data)
        return manifest.videos
    }
}
