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
//  TrackView.swift
//  Sensic
//
//  Workspace › Creation
//  A recordable track that lives inside MainTimelineView. Owns the
//  recording session state (notes + playhead) and renders the
//  three-part visual described in the design spec.
//
//  Drop this in: Views/Creation/
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

    /// True when the user has tapped the track to reveal its
    /// editing frame (white border + drag handles).
    @Published var isSelected: Bool = false

    /// Position of the track's left edge on the timeline, in
    /// seconds.  0 = aligned with the start of the timeline; a
    /// positive value moves the whole track (and its notes) to the
    /// right.  Driven by the move-drag gesture and by the left
    /// resize handle.
    @Published var trackStartSec: TimeInterval = 0

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

    // MARK: Lifecycle internals

    private func beginFreshRecording() {
        releaseAllSoundingNotes()
        playbackStartedIds.removeAll()
        notes.removeAll()
        openNoteIndex.removeAll()
        previousActive.removeAll()
        redoStack.removeAll()
        recordedDuration = 0
        isSelected = false
        trackStartSec = 0
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

                    Text("Piano")
                        .font(.system(size: Self.labelSize, weight: .regular))
                        .foregroundStyle(.white)
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

    /// Live offset from the body's drag.  Uses `@GestureState` (not
    /// `@State`) for two reasons that matter on iOS 26: the
    /// `.updating` closure lets us explicitly null out animations in
    /// the gesture's `Transaction` — which is the only knob that
    /// reliably stops SwiftUI from springing the offset between
    /// frames — and the value auto-resets to 0 when the gesture ends,
    /// in the same render tick as the recorder commit, so there's no
    /// visual jump.
    @GestureState private var dragMoveX: CGFloat = 0

    /// Resize-handle state.  Right-handle uses only `dragWidthDelta`.
    /// Left-handle uses both (offset shifts right, width shrinks by
    /// the same — so the right edge stays put).
    @State private var dragWidthDelta: CGFloat = 0
    @State private var dragLeftResizeX: CGFloat = 0

    var body: some View {
        if recorder.isRecording || recorder.recordedDuration > 0 {
            trackContent
                .overlay {
                    if recorder.isSelected {
                        selectionFrame
                    }
                }
                .offset(x: CGFloat(recorder.trackStartSec) * pixelsPerSecond
                           + dragMoveX
                           + dragLeftResizeX)
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

    // MARK: Track + tap-or-move gesture

    /// The track visual, with a unified tap-or-move gesture.  Tap
    /// (no movement) toggles selection; movement (when already
    /// selected) drags the track on the timeline.  Combining them
    /// into one `DragGesture(minimumDistance: 0)` is what lets the
    /// drag activate instantly — separate tap + drag gestures
    /// forced a `minimumDistance` of at least 1, which is what felt
    /// like a "lock" on the first 1pt of motion.
    private var trackContent: some View {
        TrackView(
            notes: recorder.notes,
            durationSeconds: effectiveDuration,
            playheadSeconds: recorder.playheadSeconds,
            pixelsPerSecond: pixelsPerSecond
        )
        .contentShape(Rectangle())
        .highPriorityGesture(tapOrMoveGesture)
    }

    private var tapOrMoveGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($dragMoveX) { value, state, transaction in
                // Kill any inherited animation — without this iOS 26
                // tries to interpolate the offset between frames,
                // which is the "lag/slow" feel.
                transaction.animation = nil
                transaction.disablesAnimations = true

                guard recorder.isSelected else {
                    state = 0   // only selected tracks move visually
                    return
                }
                let minDx = -CGFloat(recorder.trackStartSec)
                    * pixelsPerSecond
                state = max(minDx, value.translation.width)
            }
            .onEnded { value in
                let dx = value.translation.width

                // Treat a near-zero drag as a tap: toggle selection.
                if abs(dx) < 3 {
                    recorder.toggleSelection()
                    return
                }

                guard recorder.isSelected else { return }

                let minDx = -CGFloat(recorder.trackStartSec)
                    * pixelsPerSecond
                let clamped = max(minDx, dx)
                let deltaSec = TimeInterval(clamped / pixelsPerSecond)
                recorder.setTrackStartSec(
                    recorder.trackStartSec + deltaSec)
                // dragMoveX auto-resets via @GestureState in the
                // same render tick — no visual jump.
            }
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
                pixelsPerSecond: 80
            )
        }
        .padding()
    }
    .preferredColorScheme(.dark)
}
