//
//  KeyboardObserver.swift
//  Challenge
//
//  Created by Stanley Adigwe on 2026-01-12.
//

import SwiftUI
import Combine

/// Observes keyboard frame changes and publishes clean height + animation duration
/// Useful for manually positioning views above the keyboard without .ignoresSafeArea
@MainActor
final class KeyboardObserver: ObservableObject {
    
    @Published private(set) var height: CGFloat = 0
    @Published private(set) var animationDuration: Double = 0.25
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                guard let self else { return }
                guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
                
                let duration = (notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double) ?? 0.25
                
                // Calculate visible keyboard height (handles external keyboards, iPad split, etc.)
                let screenHeight = UIScreen.main.bounds.height
                let newHeight = max(0, screenHeight - frame.origin.y)
                
                // Critical: defer publish + animation to next runloop
                // Prevents "Publishing changes within view updates" crash in SwiftUI
                DispatchQueue.main.async {
                    self.animationDuration = duration
                    
                    withAnimation(.easeOut(duration: duration)) {
                        self.height = newHeight
                    }
                }
            }
            .store(in: &cancellables)
    }
}




