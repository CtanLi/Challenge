//
//  VerticalPager.swift
//  Challenge
//
//  Created by Stanley Adigwe on 2026-01-12.
//

import SwiftUI
import UIKit

import SwiftUI
import UIKit

/// Custom vertical infinite pager using UIScrollView + 3 UIHostingControllers
/// Supports async readiness gating before page change + manual commit for pool rotation
struct VerticalPager<Prev: View, Curr: View, Next: View>: UIViewControllerRepresentable {
    
    let isScrollEnabled: Bool
    let isInteractionLocked: Bool
    
    /// Called when user tries to swipe → return true only if target video is ready
    let onSwipeAttempt: @MainActor (Int) async -> Bool
    
    /// Called after successful gate → updates coordinator index & rotates pool
    let onCommit: @MainActor (Int) -> Void
    
    let prev: () -> Prev
    let current: () -> Curr
    let next: () -> Next
    
    func makeUIViewController(context: Context) -> PagerVC<Prev, Curr, Next> {
        let vc = PagerVC<Prev, Curr, Next>()
        vc.configure(
            isScrollEnabled: isScrollEnabled,
            isInteractionLocked: isInteractionLocked,
            onSwipeAttempt: onSwipeAttempt,
            onCommit: onCommit,
            prev: prev,
            current: current,
            next: next
        )
        return vc
    }
    
    func updateUIViewController(_ vc: PagerVC<Prev, Curr, Next>, context: Context) {
        vc.isScrollEnabled = isScrollEnabled
        vc.isInteractionLocked = isInteractionLocked
        vc.onSwipeAttempt = onSwipeAttempt
        vc.onCommit = onCommit
        
        // Always keep builders up-to-date
        vc.updateBuilders(prev: prev, current: current, next: next)
        
        // Only force refresh when idle (prevents flicker during transitions)
        if !vc.isTransitioning {
            vc.refreshAllSlots()
        }
    }
}

/// The actual UIKit controller managing the 3-page scroll view
final class PagerVC<Prev: View, Curr: View, Next: View>: UIViewController, UIScrollViewDelegate {
    
    var isScrollEnabled: Bool = true { didSet { applyScrollState() } }
    var isInteractionLocked: Bool = false { didSet { applyScrollState() } }
    
    var onSwipeAttempt: @MainActor (Int) async -> Bool = { _ in true }
    var onCommit: @MainActor (Int) -> Void = { _ in }
    
    private let scrollView = UIScrollView()
    
    private let prevHost = UIHostingController<AnyView>(rootView: AnyView(EmptyView()))
    private let currHost = UIHostingController<AnyView>(rootView: AnyView(EmptyView()))
    private let nextHost = UIHostingController<AnyView>(rootView: AnyView(EmptyView()))
    
    private var didInitialLayout = false
    private(set) var isTransitioning = false
    
    private var prevBuilder: (() -> AnyView)?
    private var currBuilder: (() -> AnyView)?
    private var nextBuilder: (() -> AnyView)?
    
    private var pageHeight: CGFloat { view.bounds.height }
    private var pageWidth: CGFloat { view.bounds.width }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        
        scrollView.isPagingEnabled = true
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceVertical = true
        scrollView.delegate = self
        scrollView.backgroundColor = .black
        
        view.addSubview(scrollView)
        scrollView.frame = view.bounds
        scrollView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        [prevHost, currHost, nextHost].forEach {
            addChild($0)
            scrollView.addSubview($0.view)
            $0.view.backgroundColor = .black
            $0.didMove(toParent: self)
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        scrollView.contentSize = CGSize(width: pageWidth, height: pageHeight * 3)
        
        prevHost.view.frame = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        currHost.view.frame = CGRect(x: 0, y: pageHeight, width: pageWidth, height: pageHeight)
        nextHost.view.frame = CGRect(x: 0, y: pageHeight * 2, width: pageWidth, height: pageHeight)
        
        // Center on current page at first layout or when idle
        if !didInitialLayout {
            didInitialLayout = true
            scrollView.contentOffset = CGPoint(x: 0, y: pageHeight)
        } else if !scrollView.isDragging && !scrollView.isDecelerating && !isTransitioning {
            scrollView.contentOffset = CGPoint(x: 0, y: pageHeight)
        }
        
        applyScrollState()
    }
    
    func configure(
        isScrollEnabled: Bool,
        isInteractionLocked: Bool,
        onSwipeAttempt: @escaping @MainActor (Int) async -> Bool,
        onCommit: @escaping @MainActor (Int) -> Void,
        prev: @escaping () -> Prev,
        current: @escaping () -> Curr,
        next: @escaping () -> Next
    ) {
        self.isScrollEnabled = isScrollEnabled
        self.isInteractionLocked = isInteractionLocked
        self.onSwipeAttempt = onSwipeAttempt
        self.onCommit = onCommit
        
        updateBuilders(prev: prev, current: current, next: next)
        refreshAllSlots()
    }
    
    func updateBuilders(
        prev: @escaping () -> Prev,
        current: @escaping () -> Curr,
        next: @escaping () -> Next
    ) {
        prevBuilder = { AnyView(prev()) }
        currBuilder = { AnyView(current()) }
        nextBuilder = { AnyView(next()) }
    }
    
    func refreshAllSlots() {
        guard let prevBuilder, let currBuilder, let nextBuilder else { return }
        
        UIView.performWithoutAnimation {
            prevHost.rootView = prevBuilder()
            currHost.rootView = currBuilder()
            nextHost.rootView = nextBuilder()
        }
    }
    
    private func applyScrollState() {
        scrollView.isScrollEnabled = isScrollEnabled && !isInteractionLocked && !isTransitioning
    }
    
    // MARK: - Scroll Delegate
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        // Pre-warm both directions (fire-and-forget)
        Task { @MainActor in
            _ = await onSwipeAttempt(1)
            _ = await onSwipeAttempt(-1)
        }
    }
    
    func scrollViewWillEndDragging(
        _ scrollView: UIScrollView,
        withVelocity velocity: CGPoint,
        targetContentOffset: UnsafeMutablePointer<CGPoint>
    ) {
        let h = pageHeight
        let targetY = targetContentOffset.pointee.y
        
        let direction: Int
        if targetY > h * 1.5 { direction = 1 }
        else if targetY < h * 0.5 { direction = -1 }
        else { direction = 0 }
        
        guard direction != 0 else { return }
        
        guard isScrollEnabled && !isInteractionLocked && !isTransitioning else {
            targetContentOffset.pointee.y = h
            return
        }
        
        isTransitioning = true
        applyScrollState()
        
        Task { @MainActor in
            let ready = await onSwipeAttempt(direction)
            if !ready {
                targetContentOffset.pointee.y = h
                isTransitioning = false
                applyScrollState()
            }
        }
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        finishIfSettled()
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate { finishIfSettled() }
    }
    
    /// Finalize page change after scroll settles
    private func finishIfSettled() {
        let h = pageHeight
        let y = scrollView.contentOffset.y
        
        let direction: Int
        if y >= h * 1.5 { direction = 1 }
        else if y <= h * 0.5 { direction = -1 }
        else { direction = 0 }
        
        guard direction != 0 else {
            isTransitioning = false
            applyScrollState()
            return
        }
        
        // Critical sequence:
        // 1. Tell coordinator to update index & rotate pool
        onCommit(direction)
        
        // 2. Instantly recenter scroll view on the new "current" slot
        //    (user is now looking at what was prev/next)
        scrollView.setContentOffset(CGPoint(x: 0, y: h), animated: false)
        
        // 3. No need to refresh currHost — it's already correct after rotation
        
        isTransitioning = false
        applyScrollState()
    }
}
