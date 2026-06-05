//
//  HapticEngine.swift
//  Sensic
//
//  Wraps Core Haptics to implement Sensic's per-key haptic mapping:
//
//      (1) transient event at note-on  (the hammer strike)
//      (2) continuous event while held (the held body of the note)
//      (3) parameter-curve fade on release
//
//  Differences from the demo's HapticEngineManager:
//
//   • Sensic speaks UInt8 MIDI everywhere (matches AVAudioUnitSampler).
//   • Sensic has continuous velocity instead of three tiers, so we
//     use the spec's velocity-to-intensity formulas directly rather
//     than picking one of soft/medium/hard preset rows.
//   • Sensic only ships two styles (Smooth, Punchy), and the user
//     drives them independently via the HapticSettingsCard rather
//     than through the engine's own state.
//   • Sensic exposes two sliders (intensity AND sharpness) where the
//     demo had only one — the sharpness slider acts as an offset on
//     top of the per-note base sharpness.
//
//  All settings are read live from HapticSettings.shared at note-on
//  time, so adjusting the sliders takes effect for the very next
//  press without any subscription wiring.
//

import Foundation
import CoreHaptics
import UIKit

@MainActor
final class HapticEngine {

    static let shared = HapticEngine()

    // MARK: State

    /// `false` on Simulator and on devices without a Taptic Engine
    /// (iPad and pre-iPhone-8 hardware).  All public methods become
    /// no-ops when this is false so call sites don't need to guard.
    private(set) var isSupported: Bool = false

    private var engine: CHHapticEngine?

    /// One advanced player per held note, keyed by MIDI.  We keep
    /// these around so that on release we can schedule the fade
    /// curve against the exact player that's still running.
    private var activePlayers: [UInt8: (player: CHHapticAdvancedPatternPlayer,
                                        row: HapticNoteData)] = [:]

    // MARK: Init / lifecycle

    private init() {
        isSupported = CHHapticEngine.capabilitiesForHardware().supportsHaptics
        prepareEngine()
        observeLifecycle()
    }

    private func prepareEngine() {
        guard isSupported else { return }
        do {
            let e = try CHHapticEngine()
            e.isAutoShutdownEnabled = true

            // When iOS interrupts us (audio session change, phone
            // call, etc.) the engine stops.  Drop our handle so the
            // next note-on calls `prepareEngine` again.
            e.stoppedHandler = { [weak self] reason in
                print("CHHapticEngine stopped: \(reason)")
                Task { @MainActor in self?.engine = nil }
            }
            // On reset, all in-flight players are gone.  Clear our
            // map so we don't try to send fade curves to dead
            // players, then restart.
            e.resetHandler = { [weak self] in
                print("CHHapticEngine reset")
                Task { @MainActor in
                    self?.activePlayers.removeAll()
                    try? self?.engine?.start()
                }
            }

            try e.start()
            self.engine = e
        } catch {
            print("⚠️ CHHapticEngine init failed: \(error)")
            self.engine = nil
        }
    }

    /// Bring the engine back up if it was torn down by `stoppedHandler`.
    private func ensureRunning() {
        guard isSupported else { return }
        if engine == nil {
            prepareEngine()
        } else {
            try? engine?.start()
        }
    }

    private func observeLifecycle() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(appWillResignActive),
            name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    @objc private func appWillResignActive() {
        // Cut off any held notes immediately and shut down so we
        // don't burn battery in the background.
        Task { @MainActor in
            self.stopAll()
            self.engine?.stop()
        }
    }

    @objc private func appDidBecomeActive() {
        Task { @MainActor in self.ensureRunning() }
    }

    // MARK: - Public API

    /// Fire the transient (strike) and start the continuous (held
    /// body) player for a note.  Safe to call when the same MIDI
    /// is already held — the previous player is stopped first.
    func noteOn(midi: UInt8, velocity: UInt8) {
        guard isSupported,
              let row = HapticChartLoader.shared.row(forMidi: midi)
        else { return }
        ensureRunning()
        guard let engine = engine else { return }

        // If somehow this MIDI was already running (re-trigger
        // without a paired noteOff), kill the old player so we
        // don't leak an Advanced player slot.
        if let old = activePlayers.removeValue(forKey: midi) {
            try? old.player.stop(atTime: CHHapticTimeImmediate)
        }

        // ── Velocity → 0..1 normalized ───────────────────────────
        //
        // Sensic's piano produces UInt8 velocity in the 48..112
        // range (see PianoUIView.velocityFor(touchY:)).  The
        // velocity-to-intensity formulas from the spec expect a
        // 0..1 input, so we normalize against the full MIDI range
        // (0..127) rather than 48..112.  That way a hard strike
        // (112) still leaves headroom (≈ 0.88) and a default of
        // 100 reads as a confident-but-not-max press.
        let velNorm = clamp01(Double(velocity) / 127.0)

        // ── Per-note haptic parameters (from the JSON chart) ──
        //
        // The transient and continuous intensities scale with
        // velocity using the spec's affine formulas.  Sharpness
        // comes from the per-key effective base, so different keys
        // feel different even at the same velocity.
        let baseTrInt = 0.25 + 0.75 * velNorm        // strike strength
        let baseCoInt = 0.10 + 0.45 * velNorm        // held strength
        let baseTrShp = row.effective_base_sharpness
        let baseCoShp = row.effective_base_sharpness

        // ── User-driven modifiers (read live from settings) ──
        //
        //  • intensity slider (0..1) is a direct global multiplier:
        //    0 = silent, 0.5 = half (the default), 1 = full.
        //
        //  • sharpness slider (0..1) is centered on 0.5 and offsets
        //    the per-note sharpness by ±0.25.  At 0.5 (default) the
        //    per-note value passes through unchanged.
        let settings           = HapticSettings.shared
        let intensityMul       = settings.intensity
        let sharpnessOffset    = (settings.sharpness - 0.5) * 0.5

        // ── Style modifiers (Smooth vs Punchy) ──
        //
        // Same multipliers/offsets the demo used for the matching
        // two of its five styles.  The other three (Soft, Warm,
        // Sharp) were never exposed in Sensic's UI so they're
        // intentionally absent here.
        let style              = settings.style
        let trIntStyleMul      = style.transientIntensityMultiplier
        let trShpStyleOff      = style.transientSharpnessOffset
        let coIntStyleMul      = style.continuousIntensityMultiplier
        let coShpStyleOff      = style.continuousSharpnessOffset
        let releaseStyleMul    = style.releaseTimeMultiplier

        // Combine and clamp to the Core Haptics 0..1 valid range.
        let trInt = clamp01(baseTrInt * trIntStyleMul  * intensityMul)
        let trShp = clamp01(baseTrShp + trShpStyleOff  + sharpnessOffset)
        let coInt = clamp01(baseCoInt * coIntStyleMul  * intensityMul)
        let coShp = clamp01(baseCoShp + coShpStyleOff  + sharpnessOffset)

        // ── (1) Hammer-strike transient ──
        let transient = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                .init(parameterID: .hapticIntensity, value: Float(trInt)),
                .init(parameterID: .hapticSharpness, value: Float(trShp))
            ],
            relativeTime: 0
        )

        // ── (2) Held continuous body ──
        //
        // We set `.sustained = 1` and give the event a long nominal
        // duration (30s) so the player stays alive until we
        // explicitly stop it on note-off.  The release time is
        // pre-multiplied by the style's release multiplier — Smooth
        // stretches it, Punchy shortens it.
        let continuous = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                .init(parameterID: .hapticIntensity, value: Float(coInt)),
                .init(parameterID: .hapticSharpness, value: Float(coShp)),
                .init(parameterID: .attackTime,
                      value: Float(row.default_attack_time_s)),
                .init(parameterID: .decayTime,
                      value: Float(row.default_decay_time_s)),
                .init(parameterID: .releaseTime,
                      value: Float(row.default_release_time_s * releaseStyleMul)),
                .init(parameterID: .sustained, value: 1.0)
            ],
            relativeTime: 0,
            duration: 30.0
        )

        do {
            let pattern = try CHHapticPattern(events: [transient, continuous],
                                              parameters: [])
            let player = try engine.makeAdvancedPlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
            activePlayers[midi] = (player, row)
        } catch {
            print("⚠️ HapticEngine noteOn \(midi) failed: \(error)")
        }
    }

    /// Apply the parameter-curve fade and then hard-stop the player
    /// for `midi`.  Safe to call for a MIDI that isn't currently
    /// held — it just no-ops.
    func noteOff(midi: UInt8) {
        guard isSupported,
              let entry = activePlayers.removeValue(forKey: midi)
        else { return }

        let releaseTime = max(
            0.05,
            entry.row.default_release_time_s
                * HapticSettings.shared.style.releaseTimeMultiplier
        )

        // ── (3) Parameter-curve fade to zero intensity ──
        //
        // `.hapticIntensityControl` is a meta-parameter that scales
        // every event's intensity in the running pattern; ramping
        // it 1.0 → 0.0 over `releaseTime` produces the perceived
        // release tail without abruptly cutting off.
        do {
            let curve = CHHapticParameterCurve(
                parameterID: .hapticIntensityControl,
                controlPoints: [
                    .init(relativeTime: 0,           value: 1.0),
                    .init(relativeTime: releaseTime, value: 0.0)
                ],
                relativeTime: 0
            )
            try entry.player.scheduleParameterCurve(
                curve, atTime: CHHapticTimeImmediate
            )
        } catch {
            print("⚠️ HapticEngine noteOff fade curve \(midi): \(error)")
        }

        // Hard-stop after the fade so the engine reclaims the
        // Advanced player slot.  A small grace period (50ms) lets
        // the curve finish playing before stop() cuts in.
        let player = entry.player
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64((releaseTime + 0.05) * 1_000_000_000))
            try? player.stop(atTime: CHHapticTimeImmediate)
        }
    }

    /// Immediately silence every held note.  Used on app
    /// background, on stop / scrub, and when a recording finishes
    /// playback.
    func stopAll() {
        for (_, entry) in activePlayers {
            try? entry.player.stop(atTime: CHHapticTimeImmediate)
        }
        activePlayers.removeAll()
    }

    // MARK: Helpers

    private func clamp01(_ x: Double) -> Double {
        min(1.0, max(0.0, x))
    }
}

// MARK: - HapticStyle modifiers

/// Style-specific multipliers and offsets applied on top of the
/// per-note haptic values.  Only Smooth and Punchy are exposed in
/// Sensic — the demo's other three styles (Soft, Warm, Sharp) aren't
/// surfaced in the UI so they aren't represented here.
///
/// Values are inherited unchanged from the demo for the two styles
/// that overlap, so the feel of Smooth and Punchy in Sensic matches
/// the demo exactly.
extension HapticStyle {

    var transientIntensityMultiplier: Double {
        switch self {
        case .smooth: return 0.75
        case .punchy: return 1.25
        }
    }

    var transientSharpnessOffset: Double {
        switch self {
        case .smooth: return -0.10
        case .punchy: return +0.10
        }
    }

    var continuousIntensityMultiplier: Double {
        switch self {
        case .smooth: return 1.20
        case .punchy: return 0.70
        }
    }

    var continuousSharpnessOffset: Double {
        switch self {
        case .smooth: return -0.10
        case .punchy: return +0.05
        }
    }

    var releaseTimeMultiplier: Double {
        switch self {
        case .smooth: return 1.60   // stretches the tail
        case .punchy: return 0.55   // snaps it off
        }
    }
}