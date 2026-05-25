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
//

import SwiftUI
import Combine
import UIKit

// MARK: - UIKitDragGesture

/// A UIKit pan (and optional tap) gesture wrapped as a SwiftUI
/// view.  Use as an `.overlay { }` to capture touches on the area
/// it covers.  We use this instead of SwiftUI's `DragGesture` when
/// the latter feels laggy — UIKit gesture recognizers deliver
/// touch events directly to the run loop, so they aren't subject
/// to SwiftUI's gesture/transaction interpolation.
///
/// - `onTap`:     fires on a quick tap that doesn't move.  Omit
///                (pass `nil`) on views that should only pan.
/// - `onChanged`: fires repeatedly during the pan with the
///                cumulative x-axis translation since touch start.
/// - `onEnded`:   fires once at .ended/.cancelled with the final
///                translation.  Use it to commit the drag and to
///                reset your @State translation back to zero.
struct UIKitDragGesture: UIViewRepresentable {
    var onTap: ((CGPoint) -> Void)? = nil
    var onChanged: (CGFloat) -> Void
    var onEnded: (CGFloat) -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = true

        let pan = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePan(_:)))
        pan.maximumNumberOfTouches = 1
        view.addGestureRecognizer(pan)

        if onTap != nil {
            let tap = UITapGestureRecognizer(
                target: context.coordinator,
                action: #selector(Coordinator.handleTap(_:)))
            view.addGestureRecognizer(tap)
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onTap     = onTap
        context.coordinator.onChanged = onChanged
        context.coordinator.onEnded   = onEnded
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onTap: onTap,
                    onChanged: onChanged,
                    onEnded: onEnded)
    }

    final class Coordinator: NSObject {
        var onTap: ((CGPoint) -> Void)?
        var onChanged: (CGFloat) -> Void
        var onEnded: (CGFloat) -> Void

        init(onTap: ((CGPoint) -> Void)?,
             onChanged: @escaping (CGFloat) -> Void,
             onEnded: @escaping (CGFloat) -> Void) {
            self.onTap = onTap
            self.onChanged = onChanged
            self.onEnded = onEnded
            super.init()
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            let loc = gesture.location(in: gesture.view)
            onTap?(loc)
        }

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            let tx = gesture.translation(in: gesture.view).x
            switch gesture.state {
            case .began, .changed:
                onChanged(tx)
            case .ended, .cancelled, .failed:
                onEnded(tx)
            default:
                break
            }
        }
    }
}

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

// MARK: - TrackSnapshot

/// A pure-data copy of a track's musical content, used by the
/// Copy/Paste workflow.  Lives independently of any TrackRecorder
/// instance so we can hold it on the clipboard while the original
/// keeps recording.
struct TrackSnapshot {
    let notes: [RecordedNote]
    let duration: TimeInterval
    let name: String
}

// MARK: - EditMenuAction

/// One row in the iOS edit menu.  Maps to a `UIAction` inside the
/// `UIMenu` we hand to `UIEditMenuInteraction`.
struct EditMenuAction {
    let id: String
    let title: String
    var isDestructive: Bool = false
}

// MARK: - EditMenuPresenter

/// SwiftUI wrapper around `UIEditMenuInteraction` (iOS 16+), the
/// system's native edit-menu API.  Produces the glass pill with
/// separators and the red-on-destructive treatment that the
/// reference screenshot shows — the look is OS-supplied, we just
/// provide the actions.
///
/// Drive it with two bindings on the parent view:
///   - `isPresented`: writes `true` to show the menu, `false` to
///     dismiss it.  The wrapper writes `false` back when the user
///     taps outside or picks an action.
///   - `sourcePoint`: where the menu should anchor, in this
///     wrapper's local coordinate space.  Apple positions the menu
///     just above this point (flipping below if it would clip).
struct EditMenuPresenter: UIViewRepresentable {
    @Binding var isPresented: Bool
    let sourcePoint: CGPoint
    let actions: [EditMenuAction]
    let onAction: (String) -> Void

    func makeUIView(context: Context) -> UIView {
        let view = PassthroughHostView()
        view.backgroundColor = .clear
        let interaction = UIEditMenuInteraction(
            delegate: context.coordinator)
        view.addInteraction(interaction)
        context.coordinator.interaction = interaction
        context.coordinator.parent = self
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.actions  = actions
        context.coordinator.onAction = onAction
        context.coordinator.parent   = self

        if isPresented {
            if context.coordinator.currentConfig == nil {
                let config = UIEditMenuConfiguration(
                    identifier: "track_edit_menu" as NSString,
                    sourcePoint: sourcePoint)
                context.coordinator.currentConfig = config
                context.coordinator.interaction?
                    .presentEditMenu(with: config)
            }
        } else {
            if context.coordinator.currentConfig != nil {
                context.coordinator.interaction?.dismissMenu()
                context.coordinator.currentConfig = nil
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, UIEditMenuInteractionDelegate {
        weak var interaction: UIEditMenuInteraction?
        var actions: [EditMenuAction] = []
        var onAction: ((String) -> Void)?
        var currentConfig: UIEditMenuConfiguration?
        var parent: EditMenuPresenter?

        func editMenuInteraction(
            _ interaction: UIEditMenuInteraction,
            menuFor configuration: UIEditMenuConfiguration,
            suggestedActions: [UIMenuElement]
        ) -> UIMenu? {
            let items = actions.map { item -> UIAction in
                let a = UIAction(title: item.title) { [weak self] _ in
                    self?.onAction?(item.id)
                }
                if item.isDestructive { a.attributes = .destructive }
                return a
            }
            // .displayInline lays the actions out in one row inside
            // the glass pill — matches the reference screenshot.
            return UIMenu(title: "",
                          options: .displayInline,
                          children: items)
        }

        func editMenuInteraction(
            _ interaction: UIEditMenuInteraction,
            willDismissMenuFor configuration: UIEditMenuConfiguration,
            animator: UIEditMenuInteractionAnimating
        ) {
            // Sync state back to SwiftUI after the dismissal animates.
            DispatchQueue.main.async { [weak self] in
                self?.parent?.isPresented = false
                self?.currentConfig = nil
            }
        }
    }
}

/// Lets touches fall through to underlying views; the menu is
/// presented programmatically, so this host doesn't need to
/// intercept anything.
private final class PassthroughHostView: UIView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        nil
    }
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

    private weak var pianoVM: RecordViewModel?

    /// Read-only handle to the audio destination this recorder is
    /// bound to.  Used so pasted copies can share the original
    /// recorder's piano/synth output — without it, a pasted track
    /// has no `pianoVM` set and its playback tick is a no-op.
    var audioOutput: RecordViewModel? { pianoVM }
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

    private func stopTickerIfNeeded() {
        tickCancellable?.cancel()
        tickCancellable = nil
    }

    // MARK: Lifecycle internals

    private func beginFreshRecording() {
        releaseAllSoundingNotes()
        playbackStartedIds.removeAll()
        notes.removeAll()
        openNoteIndex.removeAll()
        previousActive.removeAll()
        undoStack.removeAll()
        redoStack.removeAll()
        recordedDuration = 0
        isSelected = false
        trackStartSec = 0
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

    /// Name shown in the track's 14pt header strip.  Driven by
    /// `TrackRecorder.trackName` — the user can change it from the
    /// edit menu's Rename action.
    let trackName: String

    // MARK: Geometry

    static let bodyHeight: CGFloat       = 62
    static let headerHeight: CGFloat     = 14
    static let cornerRadius: CGFloat     = 5
    static let noteHeight: CGFloat       = 2
    static let noteCornerRadius: CGFloat = 2

    static let iconSize: CGFloat          = 10
    static let iconLeadingInset: CGFloat  = 7
    static let iconVerticalInset: CGFloat = 1
    static let labelSpacing: CGFloat      = 2
    static let labelSize: CGFloat         = 10

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
        // ZStack with header overlaying the body's top 14pt — both
        // children share the same y=0 origin, so they're literally
        // on top of each other.  The outer `.clipShape` rounds the
        // track AND clips any content (like the icon's bounding box)
        // that would otherwise leak past the track's edges.
        ZStack(alignment: .topLeading) {
            // Body fill — single rounded rectangle covering the
            // entire 62pt track frame.
            RoundedRectangle(
                cornerRadius: Self.cornerRadius,
                style: .continuous
            )
            .fill(Color("TransparentIrisBlue"))

            // Notes, positioned by (x, y) within the track.
            ForEach(notes) { note in
                noteRectangle(note)
            }

            // Header strip on top of the body's first 14pt.  Rounded
            // top corners only (so it matches the body's rounded
            // top), straight bottom (where it meets the body).
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

                    Text(trackName)
                        .font(.system(size: Self.labelSize, weight: .regular))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .padding(.leading, Self.iconLeadingInset)
            }
            .frame(maxWidth: .infinity)
            .frame(height: Self.headerHeight)
        }
        .frame(width: width,
               height: Self.bodyHeight,
               alignment: .topLeading)
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
///
/// Also hosts the editing affordances: tap-to-select, drag-to-move,
/// and edge drag handles for resizing.  When `recorder.isSelected`
/// is true, a white-stroked rectangle frames the track and two
/// vertical handle capsules sit at its left/right edges.
struct TrackOverlay: View {
    @ObservedObject var recorder: TrackRecorder

    /// pixelsPerSecond is computed by the parent from the timeline's
    /// pixelsPerBeat and the recorder's bpm.
    let pixelsPerSecond: CGFloat

    /// Fired when the user taps a track that's already selected.
    /// First arg is the tap point in the track's local coordinate
    /// space; second arg is the recorder that was tapped.  The
    /// parent (`MainTimelineView`) converts the point to its own
    /// space and presents the iOS edit menu there.
    var onRequestEditMenu: (CGPoint, TrackRecorder) -> Void

    /// Live offset from the body's drag.  Plain `@State` because
    /// the move gesture is now a UIKit `UIPanGestureRecognizer`
    /// (via `UIKitDragGesture`) — UIKit recognizers don't have an
    /// auto-resetting equivalent of `@GestureState`, so we reset
    /// this manually in the gesture's `onEnded`.
    @State private var dragMoveX: CGFloat = 0

    /// Resize-handle state.  Right-handle uses only `dragWidthDelta`.
    /// Left-handle uses both (offset shifts right, width shrinks by
    /// the same — so the right edge stays put).
    @State private var dragWidthDelta: CGFloat = 0
    @State private var dragLeftResizeX: CGFloat = 0

    var body: some View {
        if !recorder.isDeleted
            && (recorder.isRecording || recorder.recordedDuration > 0) {
            trackContent
                // UIKit pan + tap recognizer overlay.  Sits BELOW
                // the selection frame overlay so the white resize
                // handles (still SwiftUI gestures, for now) keep
                // their hit-testing priority.
                .overlay {
                    UIKitDragGesture(
                        onTap: { location in
                            // First tap selects; a subsequent tap
                            // on an already-selected track raises
                            // the edit menu instead.
                            if recorder.isSelected {
                                onRequestEditMenu(location, recorder)
                            } else {
                                recorder.toggleSelection()
                            }
                        },
                        onChanged: { tx in
                            guard recorder.isSelected else { return }
                            let minDx = -CGFloat(recorder.trackStartSec)
                                * pixelsPerSecond
                            dragMoveX = max(minDx, tx)
                        },
                        onEnded: { _ in
                            defer { dragMoveX = 0 }
                            guard recorder.isSelected else { return }
                            let deltaSec = TimeInterval(
                                dragMoveX / pixelsPerSecond)
                            recorder.setTrackStartSec(
                                recorder.trackStartSec + deltaSec)
                        }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .overlay {
                    if recorder.isSelected {
                        selectionFrame
                    }
                }
                .offset(x: CGFloat(recorder.trackStartSec) * pixelsPerSecond
                           + dragMoveX
                           + dragLeftResizeX)
                // Final defensive line: every transaction reaching
                // this view gets its animation stripped.  The .offset
                // value can change between renders for many reasons
                // (gesture state, recorder commits, scroll) and we
                // want the position to snap to each new value
                // instantly — never interpolate.
                .transaction { transaction in
                    transaction.animation = nil
                    transaction.disablesAnimations = true
                }
        } else {
            EmptyView()
        }
    }

    /// Track's visible duration during a drag.  Recorder value plus
    /// the resize width delta, so TrackView's rendered width follows
    /// the resize gesture without writing @Published every frame.
    private var effectiveDuration: TimeInterval {
        max(0,
            recorder.recordedDuration
                + TimeInterval(dragWidthDelta / pixelsPerSecond))
    }

    // MARK: Track content

    /// The track visual.  Hit-testing comes from the
    /// `UIKitDragGesture` overlay set up in `body`, not from a
    /// SwiftUI gesture on this view.
    private var trackContent: some View {
        TrackView(
            notes: recorder.notes,
            durationSeconds: effectiveDuration,
            playheadSeconds: recorder.playheadSeconds,
            pixelsPerSecond: pixelsPerSecond,
            trackName: recorder.trackName
        )
        .contentShape(Rectangle())
    }

    // MARK: Selection frame + edge handles

    /// The white-stroked rectangle that appears around the track
    /// when it's selected.  Attached via `.overlay`, so it inherits
    /// the track's exact rendered size — no separate width/height
    /// math that could drift apart.
    private var selectionFrame: some View {
        RoundedRectangle(
            cornerRadius: TrackView.cornerRadius,
            style: .continuous
        )
        .strokeBorder(.white, lineWidth: 2)
        .allowsHitTesting(false)
        // Edge handles, straddling the frame's left and right edges
        // (half outside, half inside).
        .overlay(alignment: .leading) {
            handle(side: .left).offset(x: -2)
        }
        .overlay(alignment: .trailing) {
            handle(side: .right).offset(x: 2)
        }
    }

    private enum HandleSide { case left, right }

    /// A small vertical capsule that the user drags to resize the
    /// track from one edge.  The hit area is generously expanded
    /// with `.contentShape` so the handle is comfortable to grab.
    private func handle(side: HandleSide) -> some View {
        Capsule()
            .fill(Color.black)
            .overlay(
                Capsule().stroke(.white, lineWidth: 1)
            )
            .frame(width: 4, height: 32)
            .contentShape(Rectangle()
                .inset(by: -14))   // ~32×60 hit target
            .highPriorityGesture(handleGesture(side: side))
    }

    private func handleGesture(side: HandleSide) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let tx = value.translation.width
                let baseStartPx  = CGFloat(recorder.trackStartSec)
                    * pixelsPerSecond
                let baseWidthPx  = CGFloat(recorder.recordedDuration)
                    * pixelsPerSecond
                let minWidthPx   = CGFloat(0.5) * pixelsPerSecond

                // Same animation-killing wrapper as the move gesture.
                var t = Transaction(animation: nil)
                t.disablesAnimations = true
                withTransaction(t) {
                    switch side {
                    case .left:
                        let minDx = -baseStartPx
                        let maxDx = baseWidthPx - minWidthPx
                        let clamped = min(maxDx, max(minDx, tx))
                        dragLeftResizeX = clamped
                        dragWidthDelta  = -clamped

                    case .right:
                        let minDelta = minWidthPx - baseWidthPx
                        dragWidthDelta = max(minDelta, tx)
                    }
                }
            }
            .onEnded { _ in
                switch side {
                case .left:
                    let dxSec = TimeInterval(
                        dragLeftResizeX / pixelsPerSecond)
                    recorder.setTrackStartSec(
                        recorder.trackStartSec + dxSec)
                    recorder.setRecordedDuration(
                        recorder.recordedDuration - dxSec)
                case .right:
                    let dwSec = TimeInterval(
                        dragWidthDelta / pixelsPerSecond)
                    recorder.setRecordedDuration(
                        recorder.recordedDuration + dwSec)
                }
                dragLeftResizeX = 0
                dragWidthDelta  = 0
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
                pixelsPerSecond: 80,
                trackName: "Piano"
            )
        }
        .padding()
    }
    .preferredColorScheme(.dark)
}
