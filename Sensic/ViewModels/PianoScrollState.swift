//
//  PianoScrollState.swift
//  Sensic
//

import Combine
import SwiftUI
import UIKit

/// Shared state for the scrollable piano keyboard.
/// Owns the current scroll offset and viewport width, holds a weak
/// reference to the underlying UIScrollView, and exposes both raw
/// (point-valued) and normalized (0...1) ways to read or set scroll
/// position. Used by the keyboard itself and by the PianoScroller's
/// draggable picker so the two stay in sync.
final class PianoScrollState: ObservableObject {

    // ─────────────────────────────────────────
    // MARK: - Static content geometry
    // ─────────────────────────────────────────

    /// Total width of the scrollable piano content.
    ///
    /// 51 strides between adjacent white keys + the final key's full
    /// width. Using `wKStride` (= `wKW + wKSpacing` = 58) keeps this
    /// in lock-step with the drawing code in `PianoUIView.draw(_:)`.
    /// 51 * 58 + 56 = 3014pt — the exact x of C8's right edge.
    static let totalContentWidth: CGFloat =
        CGFloat(51) * wKStride + wKW

    // ─────────────────────────────────────────
    // MARK: - Live scroll state
    // ─────────────────────────────────────────

    /// Weak reference to the UIScrollView wrapping the piano, set
    /// by `PianoSection.makeUIView` when the UIKit view is created.
    weak var scrollView: UIScrollView?

    /// Current horizontal scroll offset of the keyboard, in points.
    /// Updated by the scroll-view delegate when the user pans the
    /// keyboard, and by `setOffset(_:)` when something else (e.g.
    /// the picker) drives the scroll.
    @Published var offset: CGFloat = 0

    /// Width of the visible viewport — the scroll view's
    /// `bounds.width` after layout. Required to compute `maxOffset`.
    @Published var viewportWidth: CGFloat = 0

    // ─────────────────────────────────────────
    // MARK: - Derived
    // ─────────────────────────────────────────

    /// Maximum scrollable offset = content width − viewport width.
    /// Clamped at 0 so a viewport wider than the content can't
    /// produce a negative range.
    var maxOffset: CGFloat {
        max(0, Self.totalContentWidth - viewportWidth)
    }

    /// Current scroll position normalized to the 0...1 range.
    /// Returns 0 when there's nothing to scroll (viewport ≥ content).
    var normalizedOffset: CGFloat {
        guard maxOffset > 0 else { return 0 }
        return max(0, min(1, offset / maxOffset))
    }

    // ─────────────────────────────────────────
    // MARK: - Setters
    // ─────────────────────────────────────────

    /// Programmatically set the absolute scroll offset (points).
    /// Updates `offset` and pushes the same value to the underlying
    /// UIScrollView so the keyboard physically scrolls in sync.
    /// Both writes are guarded by equality checks to avoid redundant
    /// `@Published` events and avoid round-tripping through the
    /// scroll-view delegate when nothing actually changed.
    func setOffset(_ value: CGFloat) {
        let clamped = max(0, min(maxOffset, value))

        if offset != clamped {
            offset = clamped
        }
        if let sv = scrollView,
           sv.contentOffset.x != clamped {
            sv.setContentOffset(
                CGPoint(x: clamped, y: 0),
                animated: false
            )
        }
    }

    /// Programmatically set the scroll position via a normalized
    /// 0...1 value. Used by the PianoScroller's draggable picker.
    func setNormalizedOffset(_ norm: CGFloat) {
        let clamped = max(0, min(1, norm))
        setOffset(clamped * maxOffset)
    }
}


