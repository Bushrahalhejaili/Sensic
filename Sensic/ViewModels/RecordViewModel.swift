//
//  RecordViewModel.swift
//  Sensic
//

import Foundation
import AVFoundation
import Combine

@MainActor
final class RecordViewModel: ObservableObject {

    @Published var isRecording = false
    @Published var isPlaying = false
    @Published var activeNotes = Set<UInt8>()
    @Published var activeNoteVelocities: [UInt8: UInt8] = [:]
    @Published var noteHistory: [NoteEvent] = []
    @Published var elapsedSeconds: TimeInterval = 0
    @Published var currentSession: PracticeSession?
    @Published var completedSession: PracticeSession?

    private let audioEngine = AVAudioEngine()
    private let sampler = AVAudioUnitSampler()
    private var sessionStart: Date?
    private var timerCancellable: AnyCancellable?
    private var playbackTask: Task<Void, Never>?
    private var undoStack: [[NoteEvent]] = []
    private var redoStack: [[NoteEvent]] = []

    init() { setupAudio() }

    var canSave: Bool {
        !eventsForPlayback.isEmpty
    }

    var hasUnsavedWork: Bool {
        isRecording || canSave
    }

    var canUndo: Bool {
        !undoStack.isEmpty
    }

    var canRedo: Bool {
        !redoStack.isEmpty
    }

    var eventsForPlayback: [NoteEvent] {
        if isRecording { return noteHistory }
        if let completedSession { return completedSession.noteEvents }
        return noteHistory
    }

    var sessionTitle: String {
        currentSession?.title ?? completedSession?.title ?? "Recording"
    }

    var sessionDuration: TimeInterval {
        if isRecording { return elapsedSeconds }
        return completedSession?.durationSeconds ?? elapsedSeconds
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
        guard let url = Bundle.main.url(forResource: "gs_instruments", withExtension: "dls") else { return }
        try sampler.loadSoundBankInstrument(
            at: url,
            program: 0,
            bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB),
            bankLSB: UInt8(kAUSampler_DefaultBankLSB)
        )
    }

    // MARK: - Piano

    func noteOn(midi: UInt8, velocity: UInt8 = 100) {
        guard !isPlaying else { return }
        sampler.startNote(midi, withVelocity: velocity, onChannel: 0)
        activeNotes.insert(midi)
        activeNoteVelocities[midi] = velocity
        guard isRecording, let start = sessionStart else { return }
        pushUndoSnapshot()
        noteHistory.append(
            NoteEvent(
                midiNote: midi,
                velocity: velocity,
                timestamp: Date().timeIntervalSince(start),
                duration: 0
            )
        )
    }

    func noteOff(midi: UInt8) {
        sampler.stopNote(midi, onChannel: 0)
        activeNotes.remove(midi)
        activeNoteVelocities.removeValue(forKey: midi)
        guard isRecording, let start = sessionStart,
              let idx = noteHistory.indices.last(where: {
                  noteHistory[$0].midiNote == midi && noteHistory[$0].duration == 0
              })
        else { return }
        noteHistory[idx].duration = Date().timeIntervalSince(start) - noteHistory[idx].timestamp
    }

    // MARK: - Recording

    static func defaultSessionTitle() -> String {
        "Recording"
    }

    func startRecording(title: String? = nil) {
        stopPlayback()
        let trimmed = (title ?? Self.defaultSessionTitle())
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let resolved = trimmed.isEmpty ? Self.defaultSessionTitle() : trimmed

        currentSession = PracticeSession(title: resolved)
        completedSession = nil
        isRecording = true
        sessionStart = Date()
        elapsedSeconds = 0
        noteHistory = []
        undoStack.removeAll()
        redoStack.removeAll()
        startTimer()
    }

    @discardableResult
    func stopRecording() -> PracticeSession? {
        guard isRecording else { return completedSession }
        isRecording = false
        stopTimer()
        guard var session = currentSession else { return nil }
        session.noteEvents = noteHistory
        session.durationSeconds = elapsedSeconds
        completedSession = session
        currentSession = nil
        return session
    }

    func discardRecording() {
        stopPlayback()
        isRecording = false
        stopTimer()
        currentSession = nil
        completedSession = nil
        noteHistory = []
        elapsedSeconds = 0
        undoStack.removeAll()
        redoStack.removeAll()
        activeNoteVelocities.removeAll()
    }

    // MARK: - Playback

    func togglePlayback() {
        if isPlaying {
            stopPlayback()
        } else {
            playRecording()
        }
    }

    func playRecording() {
        let events = eventsForPlayback
        guard !events.isEmpty else { return }
        stopPlayback()
        isPlaying = true

        playbackTask = Task { [weak self] in
            guard let self else { return }
            let sorted = events.sorted { $0.timestamp < $1.timestamp }
            var lastTime: TimeInterval = 0

            for event in sorted {
                if Task.isCancelled { break }
                let wait = max(0, event.timestamp - lastTime)
                if wait > 0 {
                    try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
                }
                lastTime = event.timestamp
                await MainActor.run {
                    self.sampler.startNote(event.midiNote, withVelocity: event.velocity, onChannel: 0)
                    self.activeNotes.insert(event.midiNote)
                }
                let noteDuration = max(0.05, event.duration)
                try? await Task.sleep(nanoseconds: UInt64(noteDuration * 1_000_000_000))
                await MainActor.run {
                    self.sampler.stopNote(event.midiNote, onChannel: 0)
                    self.activeNotes.remove(event.midiNote)
                }
                lastTime = event.timestamp + noteDuration
            }

            await MainActor.run {
                self.isPlaying = false
                self.activeNotes.removeAll()
                self.activeNoteVelocities.removeAll()
            }
        }
    }

    func stopPlayback() {
        playbackTask?.cancel()
        playbackTask = nil
        isPlaying = false
        for midi in activeNotes {
            sampler.stopNote(midi, onChannel: 0)
        }
        activeNotes.removeAll()
        activeNoteVelocities.removeAll()
    }

    // MARK: - Undo / Redo

    func undo() {
        guard canUndo else { return }
        redoStack.append(noteHistory)
        noteHistory = undoStack.removeLast()
        syncSessionFromNoteHistory()
    }

    func redo() {
        guard canRedo else { return }
        undoStack.append(noteHistory)
        noteHistory = redoStack.removeLast()
        syncSessionFromNoteHistory()
    }

    private func pushUndoSnapshot() {
        undoStack.append(noteHistory)
        if undoStack.count > 40 { undoStack.removeFirst() }
        redoStack.removeAll()
    }

    private func syncSessionFromNoteHistory() {
        if var session = completedSession {
            session.noteEvents = noteHistory
            completedSession = session
        }
    }

    // MARK: - Timer

    private func startTimer() {
        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.elapsedSeconds += 1 }
    }

    private func stopTimer() {
        timerCancellable?.cancel()
        timerCancellable = nil
    }

    var formattedTime: String {
        String(format: "%02d:%02d", Int(elapsedSeconds) / 60, Int(elapsedSeconds) % 60)
    }
}
