//
//  HapticNoteData.swift
//  Sensic
//
//  Created by Bushra Hatim Alhejaili on 06/06/2026.
//



//  Codable model that mirrors one row of
//  piano_88_key_core_haptics_chart.json (one per MIDI key, A0–C8).
//
//  The JSON itself uses snake_case keys, so the property names below
//  intentionally keep that style — no CodingKeys block needed.
//

import Foundation

struct HapticNoteData: Codable, Hashable, Identifiable {
    var id: Int { midi }

    // Identity
    let note: String                 // e.g. "C4"
    let midi: Int                    // 21 … 108
    let frequency_hz: Double
    let pitch_norm_0_to_1: Double
    let pitch_class: String          // "C", "C#", …
    let octave: Int
    let octave_band: String          // "very low", "low", "mid", …
    let pitch_class_character: String
    let pitch_class_sharpness_offset: Double

    // Sharpness baselines (the haptic equivalent of pitch)
    let base_sharpness: Double
    let effective_base_sharpness: Double

    // Default (medium-velocity) haptic values — used when no
    // per-velocity preset applies.
    let default_transient_intensity_med_velocity: Double
    let default_transient_sharpness_med_velocity: Double
    let default_continuous_intensity_med_velocity: Double
    let default_continuous_sharpness_med_velocity: Double

    // Envelope (seconds).  The continuous event runs for as long as
    // the key is held; on release we apply a parameter curve that
    // fades intensity to zero across `default_release_time_s`.
    let default_attack_time_s: Double
    let default_decay_time_s: Double
    let default_release_time_s: Double

    // Velocity presets — included for reference / future tier-based
    // UI.  Sensic interpolates the medium-velocity values using the
    // spec formulas instead (see HapticEngine), so these aren't
    // read directly from this struct today.
    let soft_velocity: Double
    let soft_transient_intensity: Double
    let soft_transient_sharpness: Double
    let soft_continuous_intensity: Double
    let soft_continuous_sharpness: Double

    let medium_velocity: Double
    let medium_transient_intensity: Double
    let medium_transient_sharpness: Double
    let medium_continuous_intensity: Double
    let medium_continuous_sharpness: Double

    let hard_velocity: Double
    let hard_transient_intensity: Double
    let hard_transient_sharpness: Double
    let hard_continuous_intensity: Double
    let hard_continuous_sharpness: Double

    let recommended_pattern: String
}
