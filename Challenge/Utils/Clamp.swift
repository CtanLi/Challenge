//
//  Clamp.swift
//  Challenge
//
//  Created by Stanley Adigwe on 2026-01-12.
//

import Foundation

extension Comparable {
    /// Returns the value clamped between the given range's bounds
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

