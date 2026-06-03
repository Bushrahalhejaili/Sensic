//
//  TrackRecorder.swift
//  Sensic
//
//  Created by Bushra Hatim Alhejaili on 30/05/2026.
//
//  Source of truth for one recording session.  Owns the notes,
//  the playhead clock, the undo/redo stacks, and the binding to
//  the AudioEngine.  Extracted from TrackView.swift so the visual
//  file holds only the visual.
//


import Foundation
import Combine
import QuartzCore

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
/// Bind an `AudioEngine` with `bind(to:)`; key presses that happen
/// while `isRecording == true` become `RecordedNote` entries.
@MainActor
final class TrackRecorder: ObservableObject, Identifiable {

    /// Object-identity ID — lets `ForEach` iterate over an array of
    /// TrackRecorders without needing any extra wrapper.
    nonisolated var id: ObjectIdentifier { ObjectIdentifier(self) }

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

    /// True when the user has tapped the track to reveal its
    /// editing frame (white border + drag handles).
    @Published var isSelected: Bool = false

    /// Display name shown in the track's header.  Defaults to
    /// "Piano"; the user can change it via the edit menu's
    /// Rename action.  Per-track — renaming one track doesn't
    /// touch any others.
    @Published var trackName: String = "Piano"

    /// Position of the track's left edge on the timeline, in
    /// seconds.  0 = aligned with the start of the timeline; a
    /// positive value moves the whole track (and its notes) to the
    /// right.  Driven by the move-drag gesture and by the left
    /// resize handle.
    @Published var trackStartSec: TimeInterval = 0

    /// Vertical lane this track occupies.  0 = top row (where the
    /// primary recorder lives by default); 1 = the row directly
    /// underneath, and so on.  Each row is `TrackView.stackedRowHeight`
    /// tall, so tracks at different rows stack vertically without
    /// overlapping.  Set by `MainTimelineView`'s paste handler.
    @Published var trackRow: Int = 0

    /// Soft-deleted state.  When `true`, `TrackOverlay` renders
    /// `EmptyView()` for this recorder — the track disappears from
    /// the timeline but its notes, name, position, and undo
    /// history are all preserved so a delete can be undone.
    @Published var isDeleted: Bool = false

    /// True when there's something to undo (the undo stack has at
    /// least one entry — note or action — and we're not currently
    /// recording).
    @Published private(set) var canUndo: Bool = false

    /// True when there's something to redo (the redo stack has at
    /// least one entry and we're not currently recording).
    @Published private(set) var canRedo: Bool = false

    /// Tempo used to convert real-time seconds → musical beats so
    /// the timeline ruler advances in lockstep with recording.
    let bpm: Double = 120

    // MARK: Private state

    private var seedSeconds: TimeInterval   = 0
    private var hostStart:   CFTimeInterval = 0
    private var tickCancellable: AnyCancellable?

    private weak var pianoVM: AudioEngine?

    /// Read-only handle to the audio destination this recorder is
    /// bound to.  Used so pasted copies can share the original
    /// recorder's piano/synth output — without it, a pasted track
    /// has no `pianoVM` set and its playback tick is a no-op.
    var audioOutput: AudioEngine? { pianoVM }
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

    // MARK: Undo / redo

    /// One reversible step in the unified history.  A `.note` entry
    /// is a single recorded note that can be popped from the notes
    /// array on undo and re-appended on redo.  An `.action` entry
    /// is an arbitrary closure pair pushed from outside the
    /// recorder — used by `MainTimelineView` so track-level edits
    /// (delete, paste) flow through the same undo button.
    enum UndoEntry {
        case note(RecordedNote)
        case action(UndoableAction)
    }

    /// A track-level operation, wrapped so the recorder can store
    /// it in its undo history without knowing what it does.  The
    /// pusher supplies the do/redo and undo closures; the recorder
    /// just invokes them at the right time.
    struct UndoableAction {
        let undo: () -> Void
        let redo: () -> Void
    }

    /// Most-recent-first history.  Push on note completion and on
    /// any `pushUndoableAction(_:)` call.  Popped by `undoTapped`.
    private var undoStack: [UndoEntry] = []

    /// Entries that have been undone — popped from `undoStack`,
    /// kept here so they can be redone.  Cleared when any new
    /// undoable step is pushed (standard undo semantics).
    private var redoStack: [UndoEntry] = []

    // MARK: Re-record archive hook

    /// Fires from `beginFreshRecording()` BEFORE any state is
    /// cleared.  `MainTimelineView` plugs in here to archive the
    /// previous recording into a new snapshot-track on a different
    /// row, so pressing Record a second time doesn't erase the
    /// first take.  Kept as a plain closure (not a Combine
    /// publisher) so it can mutate SwiftUI @State directly on the
    /// MainActor.
    var willBeginFreshRecording: (() -> Void)?

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

    /// Reverse the most-recent recorded note or track-level action.
    /// No-op during active recording.  For a note entry: locates
    /// the matching note in the current `notes` array by id,
    /// removes it, and stops any sustained playback for it.  For
    /// an action entry: simply invokes the supplied `undo` closure.
    /// Either way the entry moves to `redoStack` so the next
    /// `redoTapped()` can put it back.
    func undoTapped() {
        guard !isRecording, let entry = undoStack.popLast() else { return }
        switch entry {
        case .note(let stale):
            // The note's endSeconds may have been set after we
            // captured it — look up the current copy by id so the
            // redo restores the up-to-date version.
            if let idx = notes.firstIndex(where: { $0.id == stale.id }) {
                let current = notes.remove(at: idx)
                if playbackPlayingIds.contains(current.id) {
                    pianoVM?.noteOff(midi: current.midi)
                    playbackPlayingIds.remove(current.id)
                }
                playbackStartedIds.remove(current.id)
                redoStack.append(.note(current))
            } else {
                // The note isn't in the array anymore — push the
                // stale value to redo so the redo can still work.
                redoStack.append(.note(stale))
            }

        case .action(let action):
            action.undo()
            redoStack.append(.action(action))
        }
        refreshUndoRedo()
    }

    /// Re-apply the most-recently-undone step.  No-op during active
    /// recording or when the redo stack is empty.  Mid-playback
    /// redos of notes won't sound until the next playback session.
    func redoTapped() {
        guard !isRecording, let entry = redoStack.popLast() else { return }
        switch entry {
        case .note(let n):
            notes.append(n)
            undoStack.append(.note(n))
        case .action(let action):
            action.redo()
            undoStack.append(.action(action))
        }
        refreshUndoRedo()
    }

    /// Add a reversible track-level operation to the undo history.
    /// Called by `MainTimelineView` for paste and delete so those
    /// actions can be undone with the same button that handles
    /// per-note undo.  Clears the redo stack — any new action
    /// invalidates the previous redo chain.
    func pushUndoableAction(_ action: UndoableAction) {
        undoStack.append(.action(action))
        redoStack.removeAll()
        refreshUndoRedo()
    }

    // MARK: Track editing intents (select + move + resize)

    /// Toggle the editing-frame visibility for the track.  No-op
    /// during active recording — the track shape is owned by the
    /// recording clock then.
    func toggleSelection() {
        guard !isRecording else { return }
        isSelected.toggle()
    }

    /// Set the track's left-edge position on the timeline.
    /// Clamped at 0 so the track can't slide into negative time.
    /// Called by the move-drag gesture and the left resize handle.
    func setTrackStartSec(_ sec: TimeInterval) {
        trackStartSec = max(0, sec)
    }

    /// Set the recorded track's visible width in seconds.
    /// Clamped to a 0.5s minimum so the track never collapses to
    /// zero.  Called by both resize handles.
    func setRecordedDuration(_ sec: TimeInterval) {
        recordedDuration = max(0.5, sec)
    }

    /// Rename the track.  Empty/whitespace-only input falls back to
    /// "Piano" rather than producing a blank header.  Called by the
    /// edit menu's Rename action.
    func setTrackName(_ name: String) {
        let trimmed = name.trimmingCharacters(
            in: .whitespacesAndNewlines)
        trackName = trimmed.isEmpty ? "Piano" : trimmed
    }

    /// Snapshot this track's recorded notes as `NoteEvent` values,
    /// suitable for persistence inside a `Piece`.
    ///
    /// `timeOffset` is added to each note's `timestamp` — callers
    /// that combine multiple tracks into one project pass the
    /// track's `trackStartSec` here so the saved events use
    /// absolute project time rather than per-track relative time.
    ///
    /// Notes that were still being held (`endSeconds == nil`) at
    /// the moment of capture are clamped to the track's
    /// `recordedDuration`, since a saved project shouldn't contain
    /// notes with indefinite length.
    func noteEvents(timeOffset: TimeInterval = 0) -> [NoteEvent] {
        notes.map { note in
            let end = note.endSeconds ?? recordedDuration
            return NoteEvent(
                midiNote:  note.midi,
                velocity:  note.velocity,
                timestamp: timeOffset + note.startSeconds,
                duration:  max(0, end - note.startSeconds)
            )
        }
    }

    /// Capture this track's full state as a `TrackSnapshot` for
    /// persistence inside a saved `Piece`.  Includes the timeline
    /// layout fields (`trackStartSec`, `trackRow`) so reopening the
    /// recording restores every track to the exact spot the user
    /// left it.  Track name is preserved so per-track renames
    /// survive across sessions.
    func snapshot() -> TrackSnapshot {
        TrackSnapshot(
            notes:         notes,
            duration:      recordedDuration,
            name:          trackName,
            trackStartSec: trackStartSec,
            trackRow:      trackRow
        )
    }

    /// Hydrate this recorder from a persisted snapshot, including
    /// the full timeline position (start sec + row) — unlike
    /// `loadSnapshot(_:atStartSec:)`, which is meant for paste and
    /// lets the caller pick a fresh location.  Used by
    /// `CreationView` when the user reopens a saved recording.
    func loadFully(_ snap: TrackSnapshot) {
        notes            = snap.notes
        recordedDuration = snap.duration
        trackName        = snap.name
        trackStartSec    = max(0, snap.trackStartSec)
        trackRow         = max(0, snap.trackRow)
        isSelected       = false
        isRecording      = false
        isPlayingBack    = false
        isAdvancing      = false
        isDeleted        = false
        playheadSeconds  = 0
        undoStack.removeAll()
        redoStack.removeAll()
        refreshUndoRedo()
    }

    /// "Delete" the track.  This is a SOFT delete: the visual is
    /// hidden (`TrackOverlay` checks `isDeleted` and renders
    /// `EmptyView()`) but the recorder's notes, duration, position,
    /// name, and undo history are all preserved.  That way a
    /// follow-up `undelete()` (driven by an undo) brings the track
    /// back exactly as it was.
    ///
    /// Sustained notes are released and the playhead ticker is
    /// stopped so the now-invisible track makes no further sound.
    func deleteTrack() {
        guard !isDeleted else { return }
        releaseAllSoundingNotes()
        stopTickerIfNeeded()
        isDeleted     = true
        isPlayingBack = false
        isAdvancing   = false
        isSelected    = false
    }

    /// Reverse of `deleteTrack()` — the track becomes visible
    /// again with its preserved data.  Called by the undo action
    /// pushed in `MainTimelineView` when the user undoes a delete.
    func undelete() {
        isDeleted = false
    }

    /// Populate this (fresh) recorder from a clipboard snapshot.
    /// Used when a paste action creates a new track copy of an
    /// existing one.  Pasted recorders aren't bound to the piano
    /// VM at construction; the caller is expected to call `bind(to:)`
    /// after this if they want audio output.
    func loadSnapshot(_ snap: TrackSnapshot,
                      atStartSec startSec: TimeInterval) {
        notes            = snap.notes
        recordedDuration = snap.duration
        trackName        = snap.name
        trackStartSec    = max(0, startSec)
        isSelected       = false
        isRecording      = false
        isPlayingBack    = false
        isAdvancing      = false
        isDeleted        = false
        playheadSeconds  = 0
        // Pasted tracks start without their own undo history.  The
        // primary recorder's undo button is the only one wired in
        // the UI, and the paste itself is pushed there as a single
        // `.action` entry by `MainTimelineView`.
        undoStack.removeAll()
        redoStack.removeAll()
        refreshUndoRedo()
    }

    /// Restore notes / duration / name / position from a snapshot
    /// WITHOUT touching the undo or redo stacks — the caller is
    /// expected to be inside an undo or redo closure that already
    /// owns the history bookkeeping.
    func restoreFromSnapshot(_ snap: TrackSnapshot,
                             atStartSec startSec: TimeInterval,
                             trackRow row: Int) {
        notes            = snap.notes
        recordedDuration = snap.duration
        trackName        = snap.name
        trackStartSec    = max(0, startSec)
        trackRow         = row
        isDeleted        = false
        isSelected       = false
    }

    /// Wipe playback / recording / position state without touching
    /// the undo or redo stacks.  Used by the re-record archive's
    /// REDO closure to put the recorder back into "ready to record
    /// fresh" shape after an undo restored it.
    func clearForRerecord() {
        releaseAllSoundingNotes()
        stopTickerIfNeeded()
        notes.removeAll()
        openNoteIndex.removeAll()
        previousActive.removeAll()
        playbackStartedIds.removeAll()
        playbackPlayingIds.removeAll()
        recordedDuration = 0
        trackStartSec    = 0
        playheadSeconds  = 0
        isSelected       = false
        isRecording      = false
        isPlayingBack    = false
        isAdvancing      = false
        isDeleted        = false
        // Mirrors the reset in beginFreshRecording(): if the user
        // undid a re-record (which restored a custom name onto the
        // primary), then redid it, this brings the name back to the
        // "Piano" default rather than leaving the old rename behind.
        trackName        = "Piano"
    }

    /// Drop every per-note entry from the undo and redo stacks
    /// while preserving action entries.  Used by `MainTimelineView`
    /// when archiving the current recording into a new snapshot-
    /// track: those `.note` entries reference notes that are about
    /// to be moved off this recorder, so leaving them in this
    /// recorder's history would just produce confusing no-op undos.
    func clearNoteHistory() {
        undoStack.removeAll {
            if case .note = $0 { return true }
            return false
        }
        redoStack.removeAll {
            if case .note = $0 { return true }
            return false
        }
        refreshUndoRedo()
    }

    private func stopTickerIfNeeded() {
        tickCancellable?.cancel()
        tickCancellable = nil
    }

    // MARK: Lifecycle internals

    private func beginFreshRecording() {
        // Let the parent archive the previous recording (if any)
        // BEFORE we clear notes/duration/position.  Once this
        // returns, the old data has either been copied into a
        // snapshot-track or the parent explicitly chose not to
        // preserve it (e.g. the track was already soft-deleted).
        willBeginFreshRecording?()

        releaseAllSoundingNotes()
        playbackStartedIds.removeAll()
        notes.removeAll()
        openNoteIndex.removeAll()
        previousActive.removeAll()
        // Undo and redo stacks are NOT cleared here — undo history
        // persists across recording sessions per the user's spec.
        // It only resets when they leave the recording page.
        recordedDuration = 0
        isSelected = false
        trackStartSec = 0
        // Reset the display name back to the "Piano" default so the
        // next recording starts fresh — without this, a user who
        // renamed the previous take (e.g. to "Melody") would see
        // that custom name carry over onto the new recording.  The
        // archived snapshot above keeps its name; this only resets
        // the *primary* recorder.
        trackName = "Piano"
        // A fresh recording on a previously-deleted track makes the
        // track visible again — recording into nothing wouldn't
        // make sense.
        isDeleted = false
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
    ///
    /// Note times are interpreted relative to the track's left
    /// edge, so a track moved to `trackStartSec = 5` won't fire
    /// any audio until the playhead crosses second 5 on the
    /// timeline.
    private func scheduleAudioEvents(upTo currentTime: TimeInterval) {
        guard let vm = pianoVM else { return }
        let effectiveTime = currentTime - trackStartSec
        for note in notes {
            // noteOn
            if !playbackStartedIds.contains(note.id),
               note.startSeconds <= effectiveTime {
                vm.noteOn(midi: note.midi, velocity: note.velocity)
                playbackStartedIds.insert(note.id)
                playbackPlayingIds.insert(note.id)
            }
            // noteOff
            if playbackPlayingIds.contains(note.id),
               let endSec = note.endSeconds,
               endSec <= effectiveTime {
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
        let effectiveTime = clamped - trackStartSec
        releaseAllSoundingNotes()
        playbackStartedIds.removeAll()

        for note in notes where note.startSeconds < effectiveTime {
            playbackStartedIds.insert(note.id)
        }

        playheadSeconds = clamped
        seedSeconds = clamped
        hostStart = CACurrentMediaTime()
    }

    /// Recompute `canUndo` / `canRedo` from the current state.
    /// Called from every transport intent so the UI stays in sync.
    private func refreshUndoRedo() {
        canUndo = !undoStack.isEmpty && !isRecording
        canRedo = !redoStack.isEmpty && !isRecording
    }

    // MARK: Note capture

    private func closeAllOpenNotes(at time: TimeInterval) {
        for midi in Array(openNoteIndex.keys) {
            closeNote(midi: midi, at: time)
        }
    }

    private func openNote(midi: UInt8, at time: TimeInterval, velocity: UInt8) {
        let n = RecordedNote(
            midi: midi,
            startSeconds: time,
            endSeconds: nil,
            velocity: velocity
        )
        notes.append(n)
        openNoteIndex[midi] = notes.count - 1
        // Add to history at open time so the undo order matches
        // the existing pop-LIFO behavior (most-recent-started
        // first).  `undoTapped` re-reads the note from `notes` by
        // id, so the value captured here being incomplete is fine.
        undoStack.append(.note(n))
        redoStack.removeAll()
        refreshUndoRedo()
    }

    private func closeNote(midi: UInt8, at time: TimeInterval) {
        guard let index = openNoteIndex.removeValue(forKey: midi),
              index < notes.count else { return }
        notes[index].endSeconds = time
    }

    // MARK: Note editing (used by EditSheetView / PianoRollView)

    /// Move a note to a different lane (vertical drag).  Looked up
    /// by id rather than index so the caller doesn't have to track
    /// array positions across re-renders.
    func setNoteMidi(_ noteId: UUID, _ midi: UInt8) {
        guard let idx = notes.firstIndex(where: { $0.id == noteId })
            else { return }
        notes[idx].midi = midi
    }

    /// Slide a note along the time axis (horizontal drag).
    func setNoteStart(_ noteId: UUID, _ start: TimeInterval) {
        guard let idx = notes.firstIndex(where: { $0.id == noteId })
            else { return }
        notes[idx].startSeconds = max(0, start)
    }

    /// Resize a note from the right edge.  `end` is clamped above
    /// `startSeconds` so the duration can never go negative.
    func setNoteEnd(_ noteId: UUID, _ end: TimeInterval) {
        guard let idx = notes.firstIndex(where: { $0.id == noteId })
            else { return }
        notes[idx].endSeconds = max(notes[idx].startSeconds, end)
    }

    // MARK: Note add / delete (used by PianoRollView's tap-to-add /
    //       tap-to-delete in the edit sheet)

    /// Add a new note.  Pushed as a single undoable action so the
    /// undo button removes it (and redo re-adds it), matching how
    /// paste / delete-track behave.  `recordedDuration` grows if the
    /// note runs past the current end so the timeline track contains it.
    @discardableResult
    func addNote(midi: UInt8,
                 startSeconds: TimeInterval,
                 endSeconds: TimeInterval,
                 velocity: UInt8 = 100) -> UUID {
        let start = max(0, startSeconds)
        let note = RecordedNote(midi: midi,
                                startSeconds: start,
                                endSeconds: max(start, endSeconds),
                                velocity: velocity)
        let prevDuration = recordedDuration

        insertNoteRaw(note)
        if let end = note.endSeconds {
            recordedDuration = max(recordedDuration, end)
        }

        pushUndoableAction(UndoableAction(
            undo: { [weak self] in
                self?.removeNoteRaw(note.id)
                self?.recordedDuration = prevDuration
            },
            redo: { [weak self] in
                guard let self else { return }
                self.insertNoteRaw(note)
                if let end = note.endSeconds {
                    self.recordedDuration = max(self.recordedDuration, end)
                }
            }
        ))
        return note.id
    }

    /// Delete a note by id.  Undoable (undo re-adds it, redo removes
    /// it again); releases it if it happens to be sounding.
    func deleteNote(_ id: UUID) {
        guard let note = notes.first(where: { $0.id == id }) else { return }
        removeNoteRaw(id)
        pushUndoableAction(UndoableAction(
            undo: { [weak self] in self?.insertNoteRaw(note) },
            redo: { [weak self] in self?.removeNoteRaw(id) }
        ))
    }

    /// Append a note without touching the undo stacks — the caller's
    /// `UndoableAction` owns the history.
    private func insertNoteRaw(_ note: RecordedNote) {
        guard !notes.contains(where: { $0.id == note.id }) else { return }
        notes.append(note)
    }

    /// Remove a note by id without touching the undo stacks; releases
    /// it cleanly if it's currently sounding.
    private func removeNoteRaw(_ id: UUID) {
        guard let idx = notes.firstIndex(where: { $0.id == id }) else { return }
        let removed = notes.remove(at: idx)
        if playbackPlayingIds.contains(removed.id) {
            pianoVM?.noteOff(midi: removed.midi)
            playbackPlayingIds.remove(removed.id)
        }
        playbackStartedIds.remove(removed.id)
    }

    // MARK: Piano binding

    /// Subscribe to the piano's `AudioEngine.activeNotes` so
    /// live key presses turn into recorded note events while
    /// `isRecording` is true.
    func bind(to vm: AudioEngine) {
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
