//
//  EditSheetView.swift
//  Sensic
//
//  Created by Bushra Hatim Alhejaili on 26/05/2026.
//
//  The sheet that slides up when the user taps "Edit" on a
//  track's edit menu.  Hosts the vertically-scrolling piano
//  roll (PianoRollView) which lets the user preview keys and
//  reshape the track's notes.
//

import SwiftUI

// MARK: - EditSheetView

/// Bottom sheet that appears when the user taps "Edit" on a
/// track.  Presented from `CreationView` via `.sheet(item:)` so
/// the recorder being edited is passed in directly — no extra
/// state needed to identify which track this is.
///
/// The sheet is pinned to a single 322pt detent so its size
/// doesn't drift with content.  The piano roll inside is
/// scrollable; at this height roughly twelve key-rows are
/// visible at any one time.
struct EditSheetView: View {

    /// The track whose notes are shown on the piano roll, and
    /// whose `audioOutput` the playable keys drive.
    let recorder: TrackRecorder

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

                PianoRollView(recorder: recorder)
                    // Keep the top gap below the drag indicator /
                    // nav chrome…
                    .padding(.top, 24)
                    // …but let the roll run all the way to the
                    // sheet's bottom edge.  Without this it stops
                    // at the bottom safe-area inset (the home-
                    // indicator strip), leaving a band of bare
                    // background showing through — the gap.  The
                    // background already ignores the safe area, so
                    // matching the roll to it closes the gap while
                    // the top spacing stays exactly as set above.
                    .ignoresSafeArea(.container, edges: .bottom)
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
            EditSheetView(recorder: TrackRecorder())
                .presentationDetents([.height(322)])
                .presentationDragIndicator(.visible)
        }
}


