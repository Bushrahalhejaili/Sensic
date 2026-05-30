//
//  AudioEngine.swift
//  Sensic
//
//  Created by Bushra Hatim Alhejaili on 30/05/2026.
//

import Foundation
import AVFoundation
import Combine

@MainActor
final class AudioEngine: ObservableObject {

    static let shared = AudioEngine()

    @Published var activeNotes: Set<UInt8> = []
    @Published var activeNoteVelocities: [UInt8: UInt8] = [:]

    private let audioEngine = AVAudioEngine()
    private let sampler = AVAudioUnitSampler()

    private init() {
        setupAudio()
    }

    // MARK: - Audio

    private func setupAudio() {
        audioEngine.attach(sampler)
        audioEngine.connect(sampler, to: audioEngine.mainMixerNode, format: nil)
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            try audioEngine.start()
            try loadSoundFont()
        } catch {
            print("Audio error: \(error)")
        }
    }

    private func loadSoundFont() throws {
        guard let url = Bundle.main.url(forResource: "gs_instruments",
                                        withExtension: "dls") else { return }
        try sampler.loadSoundBankInstrument(
            at: url,
            program: 0,
            bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB),
            bankLSB: UInt8(kAUSampler_DefaultBankLSB)
        )
    }

    // MARK: - Piano

    func noteOn(midi: UInt8, velocity: UInt8 = 100) {
        sampler.startNote(midi, withVelocity: velocity, onChannel: 0)
        activeNotes.insert(midi)
        activeNoteVelocities[midi] = velocity
    }

    func noteOff(midi: UInt8) {
        sampler.stopNote(midi, onChannel: 0)
        activeNotes.remove(midi)
        activeNoteVelocities.removeValue(forKey: midi)
    }

    func stopAll() {
        for midi in activeNotes {
            sampler.stopNote(midi, onChannel: 0)
        }
        activeNotes.removeAll()
        activeNoteVelocities.removeAll()
    }
}
