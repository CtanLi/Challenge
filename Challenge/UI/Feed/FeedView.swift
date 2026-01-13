//
//  FeedView.swift
//  Challenge
//
//  Created by Stanley Adigwe on 2026-01-12.
//

import SwiftUI
import AVFoundation

/// Main full-screen feed view with vertical infinite video scrolling + inline message input
struct FeedView: View {
    
    @StateObject private var keyboard = KeyboardObserver()
    @StateObject private var viewModel = FeedViewModel()
    
    @State private var inputFocused: Bool = false
    @State private var messageText: String = ""
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // Video feed layer – full screen, never resizes with keyboard
                feedLayer
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .ignoresSafeArea(.keyboard)
                    .allowsHitTesting(!inputFocused)     // Prevent accidental swipes while typing
                
                // Optional loading gate overlay during page transitions
                if viewModel.coordinator?.showLoadingGate == true {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .padding(14)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                
                // Input bar stays pinned just above keyboard
                InlineInputBar(
                    text: $messageText,
                    isFocused: $inputFocused,
                    onFocusChange: { focused in
                        DispatchQueue.main.async {
                            inputFocused = focused
                            viewModel.setTyping(focused)
                        }
                    },
                    onSend: {
                        let trimmed = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        messageText = ""
                        inputFocused = false
                        viewModel.setTyping(false)
                        // TODO: Send message to backend
                    },
                    onHeart: { /* reaction hook */ },
                    onShare: { /* reaction hook */ }
                )
                .padding(.horizontal, 14)
                .padding(.bottom, keyboard.height > 0 ? 5 : 12)
                .frame(maxWidth: .infinity)
                // Manual lift above keyboard
                .offset(y: -keyboard.height)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        // Critical: disable automatic keyboard push-up
        .ignoresSafeArea(.keyboard)
        .task {
            await viewModel.load()
        }
    }
    
    @ViewBuilder
    private var feedLayer: some View {
        if let coordinator = viewModel.coordinator {
            VerticalPager(
                // Disable swipe during typing
                isScrollEnabled: !inputFocused,
                isInteractionLocked: coordinator.showLoadingGate,
                onSwipeAttempt: { dir in
                    await coordinator.gateAdvance(direction: dir)
                },
                onCommit: { dir in
                    coordinator.commitAdvance(direction: dir)
                },
                prev:    { PlayerLayerView(player: coordinator.prevPlayer()).ignoresSafeArea() },
                current: { PlayerLayerView(player: coordinator.currentPlayer()).ignoresSafeArea() },
                next:    { PlayerLayerView(player: coordinator.nextPlayer()).ignoresSafeArea() }
            )
        } else {
            ProgressView("Loading…")
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
        }
    }
}
