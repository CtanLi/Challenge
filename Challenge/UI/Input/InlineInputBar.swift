//
//  InlineInputBar.swift
//  Challenge
//
//  Created by Stanley Adigwe on 2026-01-12.
//

import SwiftUI

/// Compact input bar that auto-grows with text (up to 5 lines),
/// shows heart/share buttons when idle, switches to send button when typing,
/// and uses ultra-thin material for a modern glass look
struct InlineInputBar: View {
    
    @Binding var text: String
    @Binding var isFocused: Bool
    
    let onFocusChange: (Bool) -> Void
    let onSend: () -> Void
    let onHeart: () -> Void
    let onShare: () -> Void
    
    @State private var measuredInputHeight: CGFloat = 44
    
    private var hasText: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        HStack(spacing: 10) {
            // Auto-sizing text input takes all available width
            AutoSizingTextView(
                text: $text,
                measuredHeight: $measuredInputHeight,
                maxLines: 5,
                isFocused: isFocused,
                onFocusChange: { focused in
                    // Only trigger change when state actually flips
                    if isFocused != focused {
                        isFocused = focused
                        onFocusChange(focused)
                    }
                },
                placeholder: "Send message"
            )
            .frame(height: max(44, measuredInputHeight))
            .frame(maxWidth: .infinity)
            .layoutPriority(1)
            
            // Button area: heart + share when not focused,
            // send button when there's text and focused
            if !isFocused {
                HStack(spacing: 8) {
                    Button(action: onHeart) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 18, weight: .semibold))
                    }
                    .accessibilityLabel("React with heart")
                    
                    Button(action: onShare) {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 18, weight: .semibold))
                    }
                    .accessibilityLabel("Share")
                }
                .foregroundStyle(.white)
                .fixedSize()
                .transition(.opacity.combined(with: .scale))
            }
            else if hasText {
                Button(action: onSend) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                }
                .foregroundStyle(.white)
                .fixedSize()
                .accessibilityLabel("Send message")
                .transition(.opacity.combined(with: .scale))
            }
        }
        .padding(10)
        .background(.ultraThinMaterial.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .animation(.easeOut(duration: 0.18), value: isFocused)
        .animation(.easeOut(duration: 0.18), value: hasText)
    }
}
