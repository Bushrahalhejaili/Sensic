//
//  EditSheetView.swift
//  Sensic
//
//  Created by Bushra Hatim Alhejaili on 26/05/2026.
//


//  Workspace › Creation
//  The sheet that slides up when the user taps "Edit" on a
//  track's edit menu.  For now it's just a system sheet with a
//  navigation toolbar and a `TransparentSpaceBlue` background —
//  the structure is in place so editing controls can be added
//  later without re-doing the presentation plumbing.
//
//  Drop this in: Views/Creation/
//

import SwiftUI

// MARK: - EditSheetView

/// Bottom sheet shown when the user taps the "Edit" action in a
/// track's edit menu.  Presented from `CreationView` via a
/// standard SwiftUI `.sheet`, pinned to a single 322pt detent so
/// the size doesn't drift with content.
///
/// The view itself is intentionally sparse: a navigation toolbar
/// (so the title bar / Done button look matches iOS conventions)
/// over a flat `TransparentSpaceBlue` background.  Real editing
/// controls will land here in a later iteration.
struct EditSheetView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        // `NavigationStack` here is purely for the chrome — it
        // gives us a system-styled navigation bar at the top of
        // the sheet, with a configurable title and toolbar slots,
        // without us having to draw a custom one.  Sits below the
        // sheet's own drag indicator (added at the call site via
        // `.presentationDragIndicator(.visible)`).
        NavigationStack {
            // `.top` alignment pins the piano roll to the upper
            // edge of the sheet's content area; the background
            // colour fills behind it.  The 24pt top padding gives
            // us the gap between the top of the sheet (just below
            // the drag indicator / nav chrome) and the first key.
            ZStack(alignment: .top) {
                Color("TransparentSpaceBlue")
                    .ignoresSafeArea()

                PianoRollView()
                    .padding(.top, 24)
            }
            // .navigationTitle("Edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // ToolbarItem(placement: .topBarTrailing) {
                //     Button("Done") { dismiss() }
                // }
            }
        }
    }
}

#Preview {
    Color.black
        .ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            EditSheetView()
                .presentationDetents([.height(322)])
                .presentationDragIndicator(.visible)
        }
}
