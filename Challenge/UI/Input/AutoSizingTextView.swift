//
//  AutoSizingTextView.swift
//  Challenge
//
//  Created by Stanley Adigwe on 2026-01-12.
//

import SwiftUI
import UIKit

/// UITextView wrapper that auto-grows up to maxLines, disables scrolling when small,
/// shows placeholder, and reports measured height back to SwiftUI for layout
struct AutoSizingTextView: UIViewRepresentable {
    
    @Binding var text: String
    @Binding var measuredHeight: CGFloat
    
    let maxLines: Int
    let isFocused: Bool
    let onFocusChange: (Bool) -> Void
    var placeholder: String = "Send message"
    
    func makeUIView(context: Context) -> ContainerView {
        let container = ContainerView()
        container.configure(placeholder: placeholder, coordinator: context.coordinator)
        
        context.coordinator.container = container
        container.textView.text = text
        context.coordinator.updatePlaceholder()
        
        // Initial sizing after first layout pass
        DispatchQueue.main.async {
            context.coordinator.updateHeightAndScrolling()
        }
        
        return container
    }
    
    func updateUIView(_ uiView: ContainerView, context: Context) {
        // Only update text programmatically when not editing
        if !uiView.textView.isFirstResponder, uiView.textView.text != text {
            uiView.textView.text = text
            context.coordinator.updatePlaceholder()
            DispatchQueue.main.async {
                context.coordinator.updateHeightAndScrolling()
            }
        }
        
        // Force focus/resign as needed
        if isFocused, !uiView.textView.isFirstResponder {
            uiView.textView.becomeFirstResponder()
        } else if !isFocused, uiView.textView.isFirstResponder {
            uiView.textView.resignFirstResponder()
        }
        
        // Re-measure after any layout change
        DispatchQueue.main.async {
            context.coordinator.updateHeightAndScrolling()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(
            text: $text,
            measuredHeight: $measuredHeight,
            maxLines: maxLines,
            onFocusChange: onFocusChange
        )
    }
    
    // MARK: - Container
    
    final class ContainerView: UIView {
        let textView = UITextView()
        let placeholderLabel = UILabel()
        
        var heightConstraint: NSLayoutConstraint?
        
        let inset = UIEdgeInsets(top: 10, left: 10, bottom: 14, right: 10)
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            backgroundColor = .clear
            
            textView.translatesAutoresizingMaskIntoConstraints = false
            placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
            
            addSubview(textView)
            addSubview(placeholderLabel)
            
            NSLayoutConstraint.activate([
                textView.leadingAnchor.constraint(equalTo: leadingAnchor),
                textView.trailingAnchor.constraint(equalTo: trailingAnchor),
                textView.topAnchor.constraint(equalTo: topAnchor),
                textView.bottomAnchor.constraint(equalTo: bottomAnchor),
                
                placeholderLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: inset.left + 2),
                placeholderLabel.topAnchor.constraint(equalTo: topAnchor, constant: inset.top)
            ])
            
            let hc = heightAnchor.constraint(equalToConstant: 44)
            hc.priority = .required
            hc.isActive = true
            heightConstraint = hc
        }
        
        required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }
        
        func configure(placeholder: String, coordinator: Coordinator) {
            textView.delegate = coordinator
            textView.backgroundColor = .clear
            textView.font = .preferredFont(forTextStyle: .body)
            textView.adjustsFontForContentSizeCategory = true
            textView.textColor = .white
            
            textView.textContainerInset = inset
            textView.textContainer.lineFragmentPadding = 0
            textView.textContainer.widthTracksTextView = true
            textView.textContainer.lineBreakMode = .byWordWrapping
            
            textView.isScrollEnabled = false          // Start off, toggle only when needed
            textView.keyboardDismissMode = .interactive
            
            placeholderLabel.text = placeholder
            placeholderLabel.textColor = UIColor.white.withAlphaComponent(0.45)
            placeholderLabel.font = textView.font
        }
    }
    
    // MARK: - Coordinator
    
    final class Coordinator: NSObject, UITextViewDelegate {
        @Binding var text: String
        @Binding var measuredHeight: CGFloat
        
        let maxLines: Int
        let onFocusChange: (Bool) -> Void
        
        weak var container: ContainerView?
        private var pending: DispatchWorkItem?
        
        init(text: Binding<String>, measuredHeight: Binding<CGFloat>, maxLines: Int, onFocusChange: @escaping (Bool) -> Void) {
            self._text = text
            self._measuredHeight = measuredHeight
            self.maxLines = maxLines
            self.onFocusChange = onFocusChange
        }
        
        func textViewDidBeginEditing(_ textView: UITextView) { onFocusChange(true) }
        func textViewDidEndEditing(_ textView: UITextView) { onFocusChange(false) }
        
        func textViewDidChange(_ textView: UITextView) {
            text = textView.text
            updatePlaceholder()
            textView.scrollRangeToVisible(textView.selectedRange)
            scheduleHeightUpdate()
        }
        
        func updatePlaceholder() {
            container?.placeholderLabel.isHidden = !text.isEmpty
        }
        
        private func scheduleHeightUpdate() {
            pending?.cancel()
            let work = DispatchWorkItem { [weak self] in
                self?.updateHeightAndScrolling()
            }
            pending = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.02, execute: work)
        }
        
        /// Measures real content height using sizeThatFits, clamps to maxLines,
        /// toggles scrolling only when content exceeds max height
        func updateHeightAndScrolling() {
            guard let container, let font = container.textView.font else { return }
            let tv = container.textView
            
            container.layoutIfNeeded()
            let width = tv.bounds.width
            guard width > 10 else { return }
            
            let inset = tv.textContainerInset
            let maxHeight = (font.lineHeight * CGFloat(maxLines)) + inset.top + inset.bottom
            
            let fitted = tv.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height
            let desired = max(44, fitted)
            let clamped = min(desired, maxHeight)
            
            let shouldScroll = desired > maxHeight + 1
            if tv.isScrollEnabled != shouldScroll {
                tv.isScrollEnabled = shouldScroll
            }
            
            if let hc = container.heightConstraint, abs(hc.constant - clamped) > 0.5 {
                hc.constant = clamped
                container.setNeedsLayout()
                container.layoutIfNeeded()
            }
            
            // Feed height back to SwiftUI for .frame(height:)
            if abs(measuredHeight - clamped) > 0.5 {
                measuredHeight = clamped
            }
            
            // Ensure cursor stays visible
            DispatchQueue.main.async {
                tv.scrollRangeToVisible(tv.selectedRange)
            }
        }
    }
}
