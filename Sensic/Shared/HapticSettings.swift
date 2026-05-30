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

import Foundation
import Combine

// MARK: - HapticStyle

enum HapticStyle {
    case smooth
    case punchy
}

// MARK: - HapticSettings

@MainActor
final class HapticSettings: ObservableObject {

    static let shared = HapticSettings()

    @Published var intensity: Double = 0.5
    @Published var sharpness: Double = 0.5
    @Published var style: HapticStyle = .smooth

    private init() {}
}
