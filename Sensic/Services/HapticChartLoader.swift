//
//  HapticChartLoader.swift
//  Sensic
//
//  Created by Bushra Hatim Alhejaili on 06/06/2026.
//



//
//  Loads piano_88_key_core_haptics_chart.json from the app bundle
//  exactly once and exposes O(1) lookup by MIDI note.
//
//  Keyed by UInt8 to match the rest of Sensic's MIDI handling
//  (AVAudioUnitSampler, AudioEngine, PianoUIView) — even though the
//  underlying JSON values are Ints, every public API here speaks
//  UInt8 so call sites don't have to keep casting.
//

import Foundation

final class HapticChartLoader {

    static let shared = HapticChartLoader()

    private(set) var rows: [HapticNoteData] = []
    private var byMidi: [UInt8: HapticNoteData] = [:]

    private init() {
        load()
    }

    /// Decode the JSON into `[HapticNoteData]` and build the
    /// MIDI-keyed lookup table.  Called once on first access.
    private func load() {
        guard let url = Bundle.main.url(
            forResource: "piano_88_key_core_haptics_chart",
            withExtension: "json"
        ) else {
            print("⚠️ HapticChartLoader: JSON resource not found in bundle.")
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode([HapticNoteData].self, from: data)
            self.rows = decoded
            self.byMidi = Dictionary(
                uniqueKeysWithValues: decoded.map { (UInt8($0.midi), $0) }
            )
        } catch {
            print("⚠️ HapticChartLoader decode error: \(error)")
        }
    }

    /// O(1) lookup by MIDI note.  Returns `nil` for any MIDI value
    /// outside the 88-key piano range (< 21 or > 108).
    func row(forMidi midi: UInt8) -> HapticNoteData? {
        byMidi[midi]
    }
}
