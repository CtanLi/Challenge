//
//  Models.swift
//  Challenge
//
//  Created by Stanley Adigwe on 2026-01-12.
//

import Foundation

/// Represents the structure of the remote manifest.json file
struct Manifest: Decodable {
    let videos: [URL]
}

struct VideoID: Hashable, Equatable {
    let raw: Int
}

struct VideoModel: Identifiable, Hashable {
    let id: VideoID
    let url: URL
}

