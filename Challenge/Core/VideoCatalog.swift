//
//  VideoCatalog.swift
//  Challenge
//
//  Created by Stanley Adigwe on 2026-01-12.
//

import Foundation

/// Holds the current list of available video URLs and provides infinite-scroll style access
final class VideoCatalog {
    
    private(set) var urls: [URL] = []
    
    func set(_ urls: [URL]) {
        self.urls = urls
    }
    
    var isEmpty: Bool { urls.isEmpty }
    
    /// Returns a VideoModel for any global index, wrapping around the available URLs in a loop
    /// (so index 0..count-1. normal, then repeats from beginning)
    func model(at globalIndex: Int) -> VideoModel {
        // Handle empty case + ensure positive wrapping
        let n = max(urls.count, 1)
        let wrapped = ((globalIndex % n) + n) % n
        
        return VideoModel(id: VideoID(raw: globalIndex), url: urls[wrapped])
    }
}

