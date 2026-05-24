//
//  TrackView.swift
//  Sensic
//
//  Created by Bushra Hatim Alhejaili on 24/05/2026.
//

//  Workspace › Creation
//  A recordable track that lives inside MainTimelineView. Owns the
//  recording session state (notes + playhead) and renders the
//  three-part visual described in the design spec.
//

import SwiftUI
import Combine

// MARK: - RecordedNote

/// A single recorded note with start and (optional, while still
/// held) end times measured in seconds from the start of the track.
struct RecordedNote: Identifiable, Equatable {
    let id = UUID()
    let midi: UInt8
    var startSeconds: TimeInterval
    var endSeconds: TimeInterval?
    let velocity: UInt8
}

// MARK: - TrackRecorder

/// Source of truth for the recording session.
///
/// Lifecycle is driven entirely by the three transport buttons:
///   - `recordTapped()` toggles capture. Toggling on resets the
///     track and playhead to 0 and starts the clock.  Toggling off
///     keeps the playhead advancing but stops accepting new notes.
///   - `playTapped()` rewinds to 0 and starts advancing in
///     playback mode.
///   - `stopTapped()` halts the playhead entirely.
///
/// The playhead position (`playheadSeconds`) advances via a 60Hz
/// timer that reads the host clock directly — so timing is accurate
/// regardless of tick jitter.
///
/// Bind a piano `RecordViewModel` with `bind(to:)`; key presses that
/// happen while `isRecording == true` become `RecordedNote` entries.
@MainActor
final class TrackRecorder: ObservableObject {

    // MARK: Observed output

    @Published private(set) var notes: [RecordedNote] = []
    @Published private(set) var isRecording:   Bool   = false
    @Published private(set) var isAdvancing:   Bool   = false
    @Published private(set) var isPlayingBack: Bool   = false
    @Published private(set) var playheadSeconds: TimeInterval = 0

    /// Length of the recorded track, in seconds.  Grows in real
    /// time while `isRecording` is true, then freezes at that value
    /// for the lifetime of the track.  Decoupled from the playhead
    /// — the playhead can drift past the end without changing this.
    @Published private(set) var recordedDuration: TimeInterval = 0

    /// True when there's something to undo (`notes` is non-empty
    /// and we're not currently recording).
    @Published private(set) var canUndo: Bool = false

    /// True when there's something to redo (the redo stack has at
    /// least one note and we're not currently recording).
    @Published private(set) var canRedo: Bool = false

    /// Tempo used to convert real-time seconds → musical beats so
    /// the timeline ruler advances in lockstep with recording.
    let bpm: Double = 120

    // MARK: Private state

    private var seedSeconds: TimeInterval   = 0
    private var hostStart:   CFTimeInterval = 0
    private var tickCancellable: AnyCancellable?

    private weak var pianoVM: RecordViewModel?
    private var pianoCancellable: AnyCancellable?
    private var previousActive: Set<UInt8> = []
    private var openNoteIndex: [UInt8: Int] = [:]

    /// IDs of notes whose `noteOn` has already been fired during the
    /// current playback session.
    private var playbackStartedIds: Set<UUID> = []

    /// IDs of notes that are currently sounding (noteOn fired,
    /// noteOff not yet). Used so we can release them cleanly on
    /// stop or re-record.
    private var playbackPlayingIds: Set<UUID> = []

    /// Notes that have been undone — popped from `notes`, kept here
    /// so they can be restored by `redoTapped()`.  Cleared whenever
    /// a fresh recording begins.
    private var redoStack: [RecordedNote] = []

    // MARK: Transport intents

    /// Toggle recording. Turning on resets the track to 0. Turning
    /// off leaves the playhead advancing.
    func recordTapped() {
        if isRecording {
            closeAllOpenNotes(at: playheadSeconds)
            isRecording = false
            // playhead keeps advancing
        } else {
            beginFreshRecording()
        }
        refreshUndoRedo()
    }

    /// Rewind to 0 and start advancing in playback mode.
    func playTapped() {
        if isRecording {
            closeAllOpenNotes(at: playheadSeconds)
            isRecording = false
        }
        // Reset playback bookkeeping so every note in `notes`
        // gets fired again from the top.
        releaseAllSoundingNotes()
        playbackStartedIds.removeAll()
        rewindPlayhead()
        isPlayingBack = true
        startAdvancing()
        refreshUndoRedo()
    }

    /// Halt the playhead and exit every advancing mode.
    func stopTapped() {
        if isRecording {
            closeAllOpenNotes(at: playheadSeconds)
            isRecording = false
        }
        releaseAllSoundingNotes()
        playbackStartedIds.removeAll()
        isPlayingBack = false
        stopAdvancing()
        refreshUndoRedo()
    }

    /// Skip the playhead 10 seconds backward.  Clamped at 0.
    /// No-op during active recording — the playhead is owned by
    /// the recording clock then and shouldn't jump around.
    func skipBackwardTapped() {
        guard !isRecording else { return }
        seekPlayhead(to: playheadSeconds - 10)
    }

    /// Skip the playhead 10 seconds forward.  Can drift past the
    /// end of the recorded track, matching the existing
    /// post-recording behavior.  No-op during active recording.
    func skipForwardTapped() {
        guard !isRecording else { return }
        seekPlayhead(to: playheadSeconds + 10)
    }

    /// Remove the most recently recorded note from the track and
    /// push it to the redo stack.  No-op during active recording.
    /// If the note is currently sounding (mid-playback), it's
    /// released so it doesn't keep ringing after disappearing
    /// visually.
    func undoTapped() {
        guard !isRecording, let last = notes.popLast() else { return }
        if playbackPlayingIds.contains(last.id) {
            pianoVM?.noteOff(midi: last.midi)
            playbackPlayingIds.remove(last.id)
        }
        playbackStartedIds.remove(last.id)
        redoStack.append(last)
        refreshUndoRedo()
    }

    /// Re-append the most recently undone note to the track.
    /// No-op during active recording or when the redo stack is
    /// empty.  Mid-playback redos won't sound until the next
    /// playback session.
    func redoTapped() {
        guard !isRecording, let next = redoStack.popLast() else { return }
        notes.append(next)
        refreshUndoRedo()
    }

    // MARK: Lifecycle internals

    private func beginFreshRecording() {
        releaseAllSoundingNotes()
        playbackStartedIds.removeAll()
        notes.removeAll()
        openNoteIndex.removeAll()
        previousActive.removeAll()
        redoStack.removeAll()
        recordedDuration = 0
        rewindPlayhead()
        isRecording = true
        isPlayingBack = false
        startAdvancing()
        refreshUndoRedo()
    }

    private func rewindPlayhead() {
        playheadSeconds = 0
        seedSeconds = 0
        hostStart = CACurrentMediaTime()
    }

    private func startAdvancing() {
        // Reseed the clock so the playhead resumes smoothly from
        // its current position even if it was already running.
        seedSeconds = playheadSeconds
        hostStart   = CACurrentMediaTime()
        guard !isAdvancing else { return }
        isAdvancing = true
        tickCancellable = Timer
            .publish(every: 1.0 / 60.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.tick() }
    }

    private func stopAdvancing() {
        isAdvancing = false
        tickCancellable = nil
    }

    private func tick() {
        guard isAdvancing else { return }
        let elapsed = CACurrentMediaTime() - hostStart
        let newTime = seedSeconds + elapsed

        // The track length grows in lockstep with the playhead, but
        // ONLY while actively recording.  Once recording stops the
        // value freezes and the playhead is free to drift past it
        // without extending the track.
        if isRecording {
            recordedDuration = newTime
        }

        // Fire any pending noteOn / noteOff events for recorded
        // notes whose times have arrived.  Done BEFORE updating
        // `playheadSeconds` so the published value matches what
        // the user is hearing.
        if isPlayingBack {
            scheduleAudioEvents(upTo: newTime)
        }

        playheadSeconds = newTime
    }

    /// Walks `notes` and, for the playback session, fires any
    /// noteOn whose `startSeconds` has been reached and any
    /// noteOff whose `endSeconds` has been reached.  Each note
    /// fires at most once per playback session thanks to
    /// `playbackStartedIds`.
    private func scheduleAudioEvents(upTo currentTime: TimeInterval) {
        guard let vm = pianoVM else { return }
        for note in notes {
            // noteOn
            if !playbackStartedIds.contains(note.id),
               note.startSeconds <= currentTime {
                vm.noteOn(midi: note.midi, velocity: note.velocity)
                playbackStartedIds.insert(note.id)
                playbackPlayingIds.insert(note.id)
            }
            // noteOff
            if playbackPlayingIds.contains(note.id),
               let endSec = note.endSeconds,
               endSec <= currentTime {
                vm.noteOff(midi: note.midi)
                playbackPlayingIds.remove(note.id)
            }
        }
    }

    /// Release any note that's currently sounding from a playback
    /// session — used when the user stops, rewinds, or starts a
    /// new recording mid-playback so nothing keeps ringing.
    private func releaseAllSoundingNotes() {
        guard let vm = pianoVM else { return }
        for note in notes where playbackPlayingIds.contains(note.id) {
            vm.noteOff(midi: note.midi)
        }
        playbackPlayingIds.removeAll()
    }

    // MARK: Seek + undo/redo support

    /// Move the playhead to an arbitrary time on the track.
    /// Clamped at 0 below (no negative time) but free to drift
    /// above `recordedDuration`.  Resets playback bookkeeping so
    /// future ticks fire the right events:
    ///   - notes whose start is before the new position are marked
    ///     as already-started (won't replay)
    ///   - notes whose start is at or after the new position will
    ///     fire when the playhead reaches them
    ///   - any currently-sounding notes are released
    private func seekPlayhead(to target: TimeInterval) {
        let clamped = max(0, target)
        releaseAllSoundingNotes()
        playbackStartedIds.removeAll()

        for note in notes where note.startSeconds < clamped {
            playbackStartedIds.insert(note.id)
        }

        playheadSeconds = clamped
        seedSeconds = clamped
        hostStart = CACurrentMediaTime()
    }

    /// Recompute `canUndo` / `canRedo` from the current state.
    /// Called from every transport intent so the UI stays in sync.
    private func refreshUndoRedo() {
        canUndo = !notes.isEmpty   && !isRecording
        canRedo = !redoStack.isEmpty && !isRecording
    }

    // MARK: Note capture

    private func closeAllOpenNotes(at time: TimeInterval) {
        for midi in Array(openNoteIndex.keys) {
            closeNote(midi: midi, at: time)
        }
    }

    private func openNote(midi: UInt8, at time: TimeInterval, velocity: UInt8) {
        notes.append(RecordedNote(
            midi: midi,
            startSeconds: time,
            endSeconds: nil,
            velocity: velocity
        ))
        openNoteIndex[midi] = notes.count - 1
    }

    private func closeNote(midi: UInt8, at time: TimeInterval) {
        guard let index = openNoteIndex.removeValue(forKey: midi),
              index < notes.count else { return }
        notes[index].endSeconds = time
    }

    // MARK: Piano binding

    /// Subscribe to the piano's `RecordViewModel.activeNotes` so
    /// live key presses turn into recorded note events while
    /// `isRecording` is true.
    func bind(to vm: RecordViewModel) {
        guard pianoVM !== vm else { return }
        pianoVM = vm
        pianoCancellable = vm.$activeNotes.sink { [weak self] newSet in
            self?.handleActiveChange(newSet)
        }
    }

    private func handleActiveChange(_ newSet: Set<UInt8>) {
        defer { previousActive = newSet }
        guard isRecording else { return }

        let added   = newSet.subtracting(previousActive)
        let removed = previousActive.subtracting(newSet)
        let now     = playheadSeconds

        for midi in added {
            let vel = pianoVM?.activeNoteVelocities[midi] ?? 100
            openNote(midi: midi, at: now, velocity: vel)
        }
        for midi in removed {
            closeNote(midi: midi, at: now)
        }
    }
}

// MARK: - TrackView

/// Visual representation of one recorded track.
///
/// Layered as:
///   - Body  — TransparentIrisBlue rectangle, 62pt tall, dynamic width
///   - Header — 14pt strip on top with rounded top corners only,
///     same fill, holds the piano icon + "Piano" label
///   - Notes — 2pt white rounded rectangles, placed by start time
///     (x) and pitch (y).  Active (still-held) notes extend to
///     `playheadSeconds`.
struct TrackView: View {

    let notes: [RecordedNote]
    let durationSeconds: TimeInterval
    let playheadSeconds: TimeInterval

    /// Pixels per second from the parent timeline. Driven by the
    /// timeline's zoom level so the track stretches and shrinks
    /// in lockstep with the ruler.
    let pixelsPerSecond: CGFloat

    // MARK: Geometry

    static let bodyHeight: CGFloat       = 62
    static let headerHeight: CGFloat     = 14
    static let cornerRadius: CGFloat     = 5
    static let noteHeight: CGFloat       = 2
    static let noteCornerRadius: CGFloat = 2

    static let iconSize: CGFloat          = 15
    static let iconLeadingInset: CGFloat  = 7
    static let iconVerticalInset: CGFloat = 1
    static let labelSpacing: CGFloat      = 2
    static let labelSize: CGFloat         = 15

    /// MIDI range used for vertical placement of notes — 88-key
    /// piano (A0..C8).
    static let midiMin: UInt8 = 21
    static let midiMax: UInt8 = 108

    /// Minimum visible width.  The track starts at 1pt the instant
    /// recording begins and grows with the playhead from there.
    static let minTrackWidth: CGFloat = 1

    private var width: CGFloat {
        max(Self.minTrackWidth, CGFloat(durationSeconds) * pixelsPerSecond)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            trackBody
            header
        }
        .frame(width: width, height: Self.bodyHeight, alignment: .topLeading)
    }

    // MARK: Header

    private var header: some View {
        ZStack(alignment: .leading) {
            UnevenRoundedRectangle(
                topLeadingRadius: Self.cornerRadius,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: Self.cornerRadius,
                style: .continuous
            )
            .fill(Color("IrisBlue"))

            HStack(spacing: Self.labelSpacing) {
                Image(systemName: "pianokeys")
                    .font(.system(size: Self.iconSize))
                    .foregroundStyle(.white)
                    .padding(.vertical, Self.iconVerticalInset)

                Text("Piano")
                    .font(.system(size: Self.labelSize, weight: .regular))
                    .foregroundStyle(.white)
            }
            .padding(.leading, Self.iconLeadingInset)
        }
        .frame(maxWidth: .infinity)
        .frame(height: Self.headerHeight)
    }

    // MARK: Body + notes

    private var trackBody: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(
                cornerRadius: Self.cornerRadius,
                style: .continuous
            )
            .fill(Color("TransparentIrisBlue"))

            ForEach(notes) { note in
                noteRectangle(note)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: Self.bodyHeight)
        .clipShape(
            RoundedRectangle(
                cornerRadius: Self.cornerRadius,
                style: .continuous
            )
        )
    }

    private func noteRectangle(_ note: RecordedNote) -> some View {
        let end = note.endSeconds ?? playheadSeconds
        let durationSec = max(0, end - note.startSeconds)
        let w = max(2, CGFloat(durationSec) * pixelsPerSecond)
        let x = CGFloat(note.startSeconds) * pixelsPerSecond

        // Constrain note placement to the area below the header so
        // high-pitch notes aren't hidden behind the IrisBlue strip.
        let yTop      = Self.headerHeight
        let yBottom   = Self.bodyHeight - Self.noteHeight
        let yRange    = yBottom - yTop
        let midiRange = CGFloat(Self.midiMax - Self.midiMin)
        let pitchNorm = CGFloat(Int(Self.midiMax) - Int(note.midi))
            / midiRange
        let y = yTop + pitchNorm * yRange

        return RoundedRectangle(
            cornerRadius: Self.noteCornerRadius,
            style: .continuous
        )
        .fill(Color.white)
        .frame(width: w, height: Self.noteHeight)
        .offset(x: x, y: y)
    }
}

// MARK: - TrackOverlay

/// Thin wrapper that observes the recorder so the parent timeline
/// body can avoid `@ObservedObject` on it and stay still during the
/// 60Hz playhead ticks.  This view is the only one that re-renders
/// per tick.
struct TrackOverlay: View {
    @ObservedObject var recorder: TrackRecorder

    /// pixelsPerSecond is computed by the parent from the timeline's
    /// pixelsPerBeat and the recorder's bpm.
    let pixelsPerSecond: CGFloat

    var body: some View {
        // Track is only generated once a recording has been
        // initiated.  Hitting play before any recording happens
        // moves the playhead but leaves the timeline empty.
        if recorder.isRecording || recorder.recordedDuration > 0 {
            TrackView(
                notes: recorder.notes,
                durationSeconds: recorder.recordedDuration,
                playheadSeconds: recorder.playheadSeconds,
                pixelsPerSecond: pixelsPerSecond
            )
        } else {
            EmptyView()
        }
    }
}

// MARK: - Preview

#Preview("TrackView") {
    ZStack {
        Color.black.ignoresSafeArea()

        VStack(spacing: 20) {
            TrackView(
                notes: [
                    RecordedNote(midi: 60, startSeconds: 0.0,
                                 endSeconds: 1.5, velocity: 100),  // C4
                    RecordedNote(midi: 64, startSeconds: 0.5,
                                 endSeconds: 2.0, velocity: 100),  // E4
                    RecordedNote(midi: 67, startSeconds: 1.0,
                                 endSeconds: 2.5, velocity: 100),  // G4
                    RecordedNote(midi: 72, startSeconds: 2.0,
                                 endSeconds: 3.5, velocity: 100),  // C5
                    RecordedNote(midi: 76, startSeconds: 2.5,
                                 endSeconds: 4.0, velocity: 100),  // E5
                ],
                durationSeconds: 4,
                playheadSeconds: 4,
                pixelsPerSecond: 80
            )
        }
        .padding()
    }
    .preferredColorScheme(.dark)
}
