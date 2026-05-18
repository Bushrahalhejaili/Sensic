//
//  PianoScrollState.swift
//  Sensic
//

import SwiftUI
import Combine

@MainActor
final class PianoScrollState: ObservableObject {
    static let totalContentWidth = CGFloat(whitePianoKeys.count) * (wKW + 1.5)

    @Published var offset: CGFloat = 0
    @Published var viewportWidth: CGFloat = 0

    weak var scrollView: PianoScrollUIView?

    var maxOffset: CGFloat {
        max(0, Self.totalContentWidth - max(viewportWidth, 1))
    }

    var normalizedOffset: CGFloat {
        guard maxOffset > 0 else { return 0 }
        return offset / maxOffset
    }

    func setOffset(_ x: CGFloat, animated: Bool = false) {
        let clamped = min(max(0, x), maxOffset)
        guard abs(clamped - offset) > 0.5 else { return }
        offset = clamped
        scrollView?.setContentOffset(CGPoint(x: clamped, y: 0), animated: animated)
    }

    func setNormalizedOffset(_ value: CGFloat, animated: Bool = false) {
        setOffset(value * maxOffset, animated: animated)
    }

    func syncFromScrollView() {
        guard let scrollView else { return }
        offset = scrollView.contentOffset.x
        viewportWidth = scrollView.bounds.width
    }
}
