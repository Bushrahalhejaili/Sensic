//
//  SensicApp.swift
//  Sensic
//
//  Created by Bushra Hatim Alhejaili on 12/05/2026.
//

import SwiftUI

@main
struct SensicApp: App {
    private let store = RecordingsStore.shared
    private let albumsStore = AlbumsStore.shared

    /// Persists across launches via UserDefaults.  Onboarding sets
    /// this to `true` when the user finishes (or skips) the flow;
    /// from then on every launch lands directly on Home.  Naming
    /// follows the existing convention used elsewhere in the
    /// project (`sensic.haptic.*`, `sensic.pieces`, ...).
    ///
    /// To reset onboarding during development, either reinstall
    /// the app or temporarily add
    /// `UserDefaults.standard.removeObject(forKey:
    /// "sensic.didCompleteOnboarding")` to the launch path.
    @AppStorage("sensic.didCompleteOnboarding")
    private var didCompleteOnboarding = false

    var body: some Scene {
        WindowGroup {
            if didCompleteOnboarding {
                HomeView(store: store, albumsStore: albumsStore)
                    .environment(store)
                    .environment(albumsStore)
            } else {
                OnboardingView()
            }
        }
    }
}


