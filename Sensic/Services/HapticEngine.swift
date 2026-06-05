//
//  HapticEngine.swift
//  Sensic
//
//  Created by Bushra Hatim Alhejaili on 06/06/2026.
//



//
//  HapticEngine.swift
//  Sensic
//
//  Wraps Core Haptics to implement Sensic's per-key haptic mapping:
//
//      (1) transient event at note-on  (the hammer strike)
//      (2) continuous event while held (the held body of the note)
//      (3) immediate stop on note-off  (haptic tracks the finger)
//
//  The third stage used to be a parameter-curve fade over the
//  note's `default_release_time_s` — that mimicked a real piano
//  string's decay but left the haptic running 50–300ms after the
//  finger lifted.  The audio sampler's soundbank already provides
//  the musical release tail, so the haptic now stops the instant
//  the finger leaves the key.
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

        // ── Per-note haptic parameters ──────────────────────────
        //
        // The transient and continuous intensities scale with
        // velocity using the spec's affine formulas.  Sharpness
        // would come from the per-key `effective_base_sharpness`
        // in the JSON chart, but the spec's value range (0.20 to
        // 0.87) leaves about 35% of Core Haptics' usable 0..1
        // sharpness range on the table.  We stretch it to
        // 0.05..0.95 below so adjacent keys are pushed slightly
        // further apart on the perceptual scale — within human
        // JND limits, every bit of headroom helps.
        //
        // We also compute a pitch-coupled balance between the
        // transient (strike) and continuous (held buzz) events.
        // The skin can't resolve 88 distinct sharpness levels —
        // adjacent notes will always sit too close on that axis to
        // feel different — so we stack a second perceptual cue on
        // top: low notes get a quieter strike but a fuller, deeper
        // held buzz; high notes get a sharper strike but barely
        // any held body.  This turns the difference between
        // registers into a qualitative shift (rumble vs click)
        // rather than just a quantitative one (more vs less
        // sharpness), which our hands read much more reliably.
        let pitchNorm  = row.pitch_norm_0_to_1            // 0 at A0, 1 at C8

        // Sharpness range capped at 0.70 (rather than the spec's
        // ~0.85 or our earlier 0.95) because Apple's Taptic Engine
        // — a Linear Resonant Actuator tuned to ~230 Hz — starts
        // losing physical amplitude as sharpness climbs past about
        // 0.70.  The engine reports the same intensity number but
        // the skin reads a noticeably thinner sensation.  Capping
        // here keeps every key in the actuator's sweet spot while
        // still leaving 0.65 of usable range — comfortably above
        // sharpness JND for the per-register differences to land.
        let baseSharp  = 0.05 + 0.65 * pitchNorm           // 0.05..0.70
        let baseTrInt  = 0.25 + 0.75 * velNorm             // strike strength
        let baseCoInt  = 0.10 + 0.45 * velNorm             // held strength
        let baseTrShp  = baseSharp                          // (was effective_base_sharpness)
        let baseCoShp  = baseSharp                          // (was effective_base_sharpness)

        // Pitch-coupled balance: transient grows with pitch,
        // continuous stays nearly flat with a tiny low-end favor.
        // The qualitative character (low notes rumblier, high notes
        // clickier) is now carried almost entirely by trPitchMul.
        // We keep a small downward slope on coPitchMul (1.15..0.95)
        // so low notes have a marginally fuller hum, but anything
        // more aggressive compounds with the sharpness cap to make
        // the top octave feel empty — which was exactly the bug we
        // chased down here.
        let trPitchMul = 0.6  + 0.8  * pitchNorm            // 0.6 → 1.4
        let coPitchMul = 1.15 - 0.20 * pitchNorm            // 1.15 → 0.95

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

        // Combine and clamp to the Core Haptics 0..1 valid range.
        // Note the extra `trPitchMul` / `coPitchMul` factor in the
        // intensity products — that's the pitch-coupled balance
        // doing its work.  Sharpness still varies with pitch only
        // through the stretched `baseSharp`; layering offsets on
        // top of an already-pitch-driven base would compress the
        // per-key differences again.
        let trInt = clamp01(baseTrInt * trIntStyleMul * intensityMul * trPitchMul)
        let trShp = clamp01(baseTrShp + trShpStyleOff + sharpnessOffset)
        let coInt = clamp01(baseCoInt * coIntStyleMul * intensityMul * coPitchMul)
        let coShp = clamp01(baseCoShp + coShpStyleOff + sharpnessOffset)

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
        // explicitly stop it on note-off.
        //
        // Note: there is intentionally NO `.releaseTime` parameter
        // here.  The original spec called for a release fade that
        // mimicked a real piano string's decay, but in practice
        // that fade made the haptic feel disconnected from the
        // finger — you'd lift off and the buzz would linger up to
        // ~300ms on low notes.  The audio sampler still produces a
        // natural release tail in the soundbank, so dropping the
        // haptic instantly on note-off keeps the *sound* musical
        // while the *touch* tracks the finger.
        let continuous = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                .init(parameterID: .hapticIntensity, value: Float(coInt)),
                .init(parameterID: .hapticSharpness, value: Float(coShp)),
                .init(parameterID: .attackTime,
                      value: Float(row.default_attack_time_s)),
                .init(parameterID: .decayTime,
                      value: Float(row.default_decay_time_s)),
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

    /// Stop the haptic for `midi` immediately when the finger
    /// lifts.  Safe to call for a MIDI that isn't currently held —
    /// it just no-ops.
    func noteOff(midi: UInt8) {
        guard isSupported,
              let entry = activePlayers.removeValue(forKey: midi)
        else { return }

        // Hard-stop, no fade.  An earlier version of this function
        // scheduled a `.hapticIntensityControl` parameter curve
        // fading 1.0 → 0.0 over the note's `default_release_time_s`,
        // then stopped the player after the fade.  That mimicked a
        // real piano's release tail but left the haptic running for
        // 50–300ms after the finger left the key — long enough to
        // feel disconnected from the touch.  Since the audio
        // sampler's own envelope provides the musical release, we
        // let touch be touch and cut the buzz the moment the finger
        // lifts.
        try? entry.player.stop(atTime: CHHapticTimeImmediate)
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
}
