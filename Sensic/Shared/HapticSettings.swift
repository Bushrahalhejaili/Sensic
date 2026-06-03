//
//  HapticSettings.swift
//  Sensic
//
//  Created by Bushra Hatim Alhejaili on 31/05/2026.
//
//  Shared haptic settings — consumed by HapticSettingsCard in both
//  Record and Practice modes. UI state only for now; the actual
//  Core Haptics engine will be added in a follow-up.
//

//
//  HapticSettings.swift
//  Sensic
//
//  Created by Bushra Hatim Alhejaili on 31/05/2026.
//


//  Shared haptic settings — consumed by HapticSettingsCard in both
//  Record and Practice modes. The three properties (intensity,
//  sharpness, style) persist to UserDefaults so the user's
//  adjustments survive between app launches. UI state only for
//  now; the actual Core Haptics engine will be added in a
//  follow-up and will read these same values.
//

import Foundation
import Combine

// MARK: - HapticStyle

enum HapticStyle: String {
    case smooth
    case punchy
}

// MARK: - HapticSettings

@MainActor
final class HapticSettings: ObservableObject {

    static let shared = HapticSettings()

    // Each property writes itself to UserDefaults whenever it
    // changes. didSet doesn't fire during init's initial
    // assignment, so loading from defaults at startup doesn't
    // bounce a write back — only actual user adjustments do.
    @Published var intensity: Double {
        didSet { defaults.set(intensity, forKey: Keys.intensity) }
    }

    @Published var sharpness: Double {
        didSet { defaults.set(sharpness, forKey: Keys.sharpness) }
    }

    @Published var style: HapticStyle {
        didSet { defaults.set(style.rawValue, forKey: Keys.style) }
    }

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let intensity = "sensic.haptic.intensity"
        static let sharpness = "sensic.haptic.sharpness"
        static let style     = "sensic.haptic.style"
    }

    private init() {
        // Load each property from UserDefaults if a value is stored,
        // otherwise fall back to the design default.
        //
        // The doubles use `.object(forKey:)` rather than
        // `.double(forKey:)` because the latter returns 0 for a
        // missing key — and 0 is itself a valid intensity/sharpness
        // value we don't want to confuse with "unset".
        if let value = defaults.object(forKey: Keys.intensity) as? Double {
            intensity = value
        } else {
            intensity = 0.5
        }

        if let value = defaults.object(forKey: Keys.sharpness) as? Double {
            sharpness = value
        } else {
            sharpness = 0.5
        }

        if let raw = defaults.string(forKey: Keys.style),
           let loaded = HapticStyle(rawValue: raw) {
            style = loaded
        } else {
            style = .smooth
        }
    }
}
