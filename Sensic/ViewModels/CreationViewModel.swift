// RecordViewModel.swift
// Sensic

import Foundation
import AVFoundation
import Combine

@MainActor
final class CreationViewModel: ObservableObject {

    // ─────────────────────────────────────────
    // MARK: - State
    // ─────────────────────────────────────────

    @Published var isRecording    = false
    @Published var activeNotes    = Set<UInt8>()
    @Published var noteHistory    = [NoteEvent]()
    @Published var elapsedSeconds: TimeInterval = 0
    @Published var currentSession: PracticeSession?

    // ─────────────────────────────────────────
    // MARK: - Audio
    // ─────────────────────────────────────────

    private let audioEngine = AVAudioEngine()
    private let sampler     = AVAudioUnitSampler()
    private var sessionStart: Date?
    private var timerCancellable: AnyCancellable?

    init() { setupAudio() }

    private func setupAudio() {
        audioEngine.attach(sampler)
        audioEngine.connect(sampler, to: audioEngine.mainMixerNode, format: nil)
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            try audioEngine.start()
            try loadSoundFont()
        } catch { print("Audio error: \(error)") }
    }

    private func loadSoundFont() throws {
        guard let url = Bundle.main.url(forResource: "gs_instruments", withExtension: "dls") else { return }
        try sampler.loadSoundBankInstrument(
            at: url, program: 0,
            bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB),
            bankLSB: UInt8(kAUSampler_DefaultBankLSB)
        )
    }

    // ─────────────────────────────────────────
    // MARK: - Piano
    // ─────────────────────────────────────────

    func noteOn(midi: UInt8, velocity: UInt8 = 100) {
        sampler.startNote(midi, withVelocity: velocity, onChannel: 0)
        activeNotes.insert(midi)
        guard isRecording, let start = sessionStart else { return }
        noteHistory.append(NoteEvent(
            midiNote: midi, velocity: velocity,
            timestamp: Date().timeIntervalSince(start), duration: 0
        ))
    }

    func noteOff(midi: UInt8) {
        sampler.stopNote(midi, onChannel: 0)
        activeNotes.remove(midi)
        guard isRecording, let start = sessionStart,
              let idx = noteHistory.indices.last(where: {
                  noteHistory[$0].midiNote == midi && noteHistory[$0].duration == 0
              }) else { return }
        noteHistory[idx].duration = Date().timeIntervalSince(start) - noteHistory[idx].timestamp
    }

    // ─────────────────────────────────────────
    // MARK: - Recording
    // ─────────────────────────────────────────

    func startRecording(title: String) {
        currentSession = PracticeSession(title: title)
        isRecording    = true
        sessionStart   = Date()
        elapsedSeconds = 0
        noteHistory    = []
        startTimer()
    }

    func stopRecording() -> PracticeSession? {
        isRecording = false
        stopTimer()
        guard var session = currentSession else { return nil }
        session.noteEvents      = noteHistory
        session.durationSeconds = elapsedSeconds
        currentSession = nil
        return session
    }

    func discardRecording() {
        isRecording    = false
        stopTimer()
        currentSession = nil
        noteHistory    = []
        elapsedSeconds = 0
    }

    // ─────────────────────────────────────────
    // MARK: - Timer
    // ─────────────────────────────────────────

    private func startTimer() {
        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect().sink { [weak self] _ in self?.elapsedSeconds += 1 }
    }

    private func stopTimer() { timerCancellable?.cancel(); timerCancellable = nil }

    var formattedTime: String {
        String(format: "%02d:%02d", Int(elapsedSeconds) / 60, Int(elapsedSeconds) % 60)
    }
}

