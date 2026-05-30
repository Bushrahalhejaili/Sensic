//
//  UIKitDragGesture.swift
//  Sensic
//
//  Created by Bushra Hatim Alhejaili on 30/05/2026.
//

import SwiftUI
import UIKit

// MARK: - UIKitDragGesture

/// A UIKit pan (and optional tap) gesture wrapped as a SwiftUI
/// view.  Use as an `.overlay { }` to capture touches on the area
/// it covers.  We use this instead of SwiftUI's `DragGesture` when
/// the latter feels laggy — UIKit gesture recognizers deliver
/// touch events directly to the run loop, so they aren't subject
/// to SwiftUI's gesture/transaction interpolation.
///
/// - `onTap`:     fires on a quick tap that doesn't move.  Omit
///                (pass `nil`) on views that should only pan.
/// - `onChanged`: fires repeatedly during the pan with the
///                cumulative translation (x, y) since touch start.
///                Sites that only care about horizontal motion can
///                just read `.x` and ignore `.y`.
/// - `onEnded`:   fires once at .ended/.cancelled with the final
///                translation.  Use it to commit the drag and to
///                reset any @State translation back to zero.
struct UIKitDragGesture: UIViewRepresentable {
    var onTap: ((CGPoint) -> Void)? = nil
    var onChanged: (CGPoint) -> Void
    var onEnded: (CGPoint) -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = true

        let pan = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePan(_:)))
        pan.maximumNumberOfTouches = 1
        view.addGestureRecognizer(pan)

        if onTap != nil {
            let tap = UITapGestureRecognizer(
                target: context.coordinator,
                action: #selector(Coordinator.handleTap(_:)))
            view.addGestureRecognizer(tap)
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onTap     = onTap
        context.coordinator.onChanged = onChanged
        context.coordinator.onEnded   = onEnded
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onTap: onTap,
                    onChanged: onChanged,
                    onEnded: onEnded)
    }

    final class Coordinator: NSObject {
        var onTap: ((CGPoint) -> Void)?
        var onChanged: (CGPoint) -> Void
        var onEnded: (CGPoint) -> Void

        init(onTap: ((CGPoint) -> Void)?,
             onChanged: @escaping (CGPoint) -> Void,
             onEnded: @escaping (CGPoint) -> Void) {
            self.onTap = onTap
            self.onChanged = onChanged
            self.onEnded = onEnded
            super.init()
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            let loc = gesture.location(in: gesture.view)
            onTap?(loc)
        }

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            let t = gesture.translation(in: gesture.view)
            switch gesture.state {
            case .began, .changed:
                onChanged(t)
            case .ended, .cancelled, .failed:
                onEnded(t)
            default:
                break
            }
        }
    }
}
