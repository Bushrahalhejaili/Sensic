//
//  PianoScroller.swift
//  Sensic
//
//  Created by Bushra Hatim Alhejaili on 23/05/2026.
//


import SwiftUI

// ─────────────────────────────────────────────
// MARK: - PianoScroller
//
//   Minimap-style strip that sits above the piano
//   keyboard and shows the current scroll window.
//
//   Stage 1 (this file): the empty container
//   rectangle only. Lines + picker will be added
//   in the next iterations.
// ─────────────────────────────────────────────

struct PianoScroller: View {

    // Container dimensions (exact spec).
    static let width: CGFloat          = 392
    static let height: CGFloat         = 45
    static let cornerRadius: CGFloat   = 20
    static let strokeWidth: CGFloat    = 1

    var body: some View {
        RoundedRectangle(
            cornerRadius: Self.cornerRadius,
            style: .continuous
        )
        .fill(Color("Navy"))
        .overlay(
            RoundedRectangle(
                cornerRadius: Self.cornerRadius,
                style: .continuous
            )
            .strokeBorder(Color("MainPurple"), lineWidth: Self.strokeWidth)
        )
        .frame(width: Self.width, height: Self.height)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        PianoScroller()
    }
    .preferredColorScheme(.dark)
}