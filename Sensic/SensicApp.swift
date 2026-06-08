//
//  SensicApp.swift
//  Sensic
//
//  Created by Bushra Hatim Alhejaili on 12/05/2026.
//

//
//  SensicApp.swift
//  Sensic
//
//  Created by Bushra Hatim Alhejaili on 12/05/2026.
//

import SwiftUI
import UIKit

@main
struct SensicApp: App {
    /// Hooks `AppDelegate` into the SwiftUI lifecycle so its
    /// `application(_:supportedInterfaceOrientationsFor:)`
    /// callback is the source of truth for which orientations the
    /// app currently supports.  The actual lock is driven by
    /// `AppOrientation.lock(to:)` from the view layer — see
    /// `CreationView`, which unlocks to landscape only while in
    /// Record mode and re-locks back to portrait when the user
    /// switches to Practice or leaves the view.
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

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

// ─────────────────────────────────────────────
// MARK: - Orientation lock
// ─────────────────────────────────────────────

/// Single source of truth for which orientations the app
/// currently supports.  Defaults to `.portrait` — the app starts
/// locked and stays that way everywhere except inside Record mode
/// in `CreationView`, which calls `AppOrientation.lock(to:)` to
/// open up `.allButUpsideDown`.  Switching to the Practice tab,
/// or popping back to a previous screen, resets the mask to
/// `.portrait` and rotates any active landscape orientation back.
final class AppDelegate: NSObject, UIApplicationDelegate {

    /// Read by `application(_:supportedInterfaceOrientationsFor:)`
    /// whenever the system asks the app what it supports.  Static
    /// so any view can mutate it without holding a reference to
    /// the delegate instance.
    static var orientationLock: UIInterfaceOrientationMask = .portrait

    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        AppDelegate.orientationLock
    }
}

/// Helper for views to change the supported orientation mask.
/// Mutates `AppDelegate.orientationLock` and asks the active
/// `UIWindowScene` to update its geometry — this is what triggers
/// the rotation animation when the lock narrows (e.g. landscape
/// → portrait when leaving Record mode).
enum AppOrientation {

    /// Updates the lock and rotates the active scene if needed.
    /// Idempotent — no-op when the mask is already what's
    /// requested.
    static func lock(to mask: UIInterfaceOrientationMask) {
        guard AppDelegate.orientationLock != mask else { return }
        AppDelegate.orientationLock = mask

        // Dispatch async so the call is safe from inside a
        // SwiftUI body / state change.  Touching scene geometry
        // synchronously during a view update can deadlock the
        // window scene.
        DispatchQueue.main.async {
            let scenes = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }

            for scene in scenes {
                scene.requestGeometryUpdate(
                    .iOS(interfaceOrientations: mask)
                ) { _ in
                    // Errors here are typically "rotation already
                    // in progress" — safe to ignore; iOS will
                    // settle on the new mask on the next pass.
                }
            }

            scenes
                .flatMap { $0.windows }
                .compactMap { $0.rootViewController }
                .forEach { $0.setNeedsUpdateOfSupportedInterfaceOrientations() }
        }
    }
}
