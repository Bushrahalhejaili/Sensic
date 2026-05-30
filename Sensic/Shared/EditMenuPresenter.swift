//
//  EditMenuPresenter.swift
//  Sensic
//
//  Created by Bushra Hatim Alhejaili on 30/05/2026.
//


import SwiftUI
import UIKit

// MARK: - EditMenuAction

/// One row in the iOS edit menu.  Maps to a `UIAction` inside the
/// `UIMenu` we hand to `UIEditMenuInteraction`.
struct EditMenuAction {
    let id: String
    let title: String
    var isDestructive: Bool = false
}

// MARK: - EditMenuPresenter

/// SwiftUI wrapper around `UIEditMenuInteraction` (iOS 16+), the
/// system's native edit-menu API.  Produces the glass pill with
/// separators and the red-on-destructive treatment that the
/// reference screenshot shows — the look is OS-supplied, we just
/// provide the actions.
///
/// Drive it with two bindings on the parent view:
///   - `isPresented`: writes `true` to show the menu, `false` to
///     dismiss it.  The wrapper writes `false` back when the user
///     taps outside or picks an action.
///   - `sourcePoint`: where the menu should anchor, in this
///     wrapper's local coordinate space.  Apple positions the menu
///     just above this point (flipping below if it would clip).
struct EditMenuPresenter: UIViewRepresentable {
    @Binding var isPresented: Bool
    let sourcePoint: CGPoint
    let actions: [EditMenuAction]
    let onAction: (String) -> Void

    func makeUIView(context: Context) -> UIView {
        let view = PassthroughHostView()
        view.backgroundColor = .clear
        let interaction = UIEditMenuInteraction(
            delegate: context.coordinator)
        view.addInteraction(interaction)
        context.coordinator.interaction = interaction
        context.coordinator.parent = self
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.actions  = actions
        context.coordinator.onAction = onAction
        context.coordinator.parent   = self

        if isPresented {
            if context.coordinator.currentConfig == nil {
                let config = UIEditMenuConfiguration(
                    identifier: "track_edit_menu" as NSString,
                    sourcePoint: sourcePoint)
                context.coordinator.currentConfig = config
                context.coordinator.interaction?
                    .presentEditMenu(with: config)
            }
        } else {
            if context.coordinator.currentConfig != nil {
                context.coordinator.interaction?.dismissMenu()
                context.coordinator.currentConfig = nil
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, UIEditMenuInteractionDelegate {
        weak var interaction: UIEditMenuInteraction?
        var actions: [EditMenuAction] = []
        var onAction: ((String) -> Void)?
        var currentConfig: UIEditMenuConfiguration?
        var parent: EditMenuPresenter?

        func editMenuInteraction(
            _ interaction: UIEditMenuInteraction,
            menuFor configuration: UIEditMenuConfiguration,
            suggestedActions: [UIMenuElement]
        ) -> UIMenu? {
            let items = actions.map { item -> UIAction in
                let a = UIAction(title: item.title) { [weak self] _ in
                    self?.onAction?(item.id)
                }
                if item.isDestructive { a.attributes = .destructive }
                return a
            }
            // .displayInline lays the actions out in one row inside
            // the glass pill — matches the reference screenshot.
            return UIMenu(title: "",
                          options: .displayInline,
                          children: items)
        }

        func editMenuInteraction(
            _ interaction: UIEditMenuInteraction,
            willDismissMenuFor configuration: UIEditMenuConfiguration,
            animator: UIEditMenuInteractionAnimating
        ) {
            // Sync state back to SwiftUI after the dismissal animates.
            DispatchQueue.main.async { [weak self] in
                self?.parent?.isPresented = false
                self?.currentConfig = nil
            }
        }
    }
}

// MARK: - PassthroughHostView

/// Lets touches fall through to underlying views; the menu is
/// presented programmatically, so this host doesn't need to
/// intercept anything.
private final class PassthroughHostView: UIView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        nil
    }
}
