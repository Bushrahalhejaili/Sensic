//
//  TrackView.swift
//  Sensic
//
//  Created by Bushra Hatim Alhejaili on 24/05/2026.
//
//  Visual representation of a recordable track, plus the
//  TrackOverlay wrapper that handles selection / move / resize
//  affordances.  All the state (notes, playhead, recording
//  lifecycle, undo/redo) lives on `TrackRecorder` — see
//  ViewModels/TrackRecorder.swift
//

//
//  TrackView.swift
//  Sensic
//
//  Created by Bushra Hatim Alhejaili on 24/05/2026.
//
//  Visual representation of a recordable track, plus the
//  TrackOverlay wrapper that handles selection / move / resize
//  affordances.  All the state (notes, playhead, recording
//  lifecycle, undo/redo) lives on `TrackRecorder` — see
//  ViewModels/TrackRecorder.swift
//

import SwiftUI

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

    /// Vertical distance between adjacent stacked tracks.  Equals
    /// `bodyHeight` plus a small breathing gap so the header strip
    /// of the lower track doesn't kiss the body of the upper one.
    /// Used by `TrackOverlay` to translate `TrackRecorder.trackRow`
    /// into a Y offset.
    static let stackedRowHeight: CGFloat = 70
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

    /// Vertical drag offset.  Lets the user reposition a track
    /// across rows by dragging up or down — on release we snap the
    /// nearest row index into `recorder.trackRow`.  Independent of
    /// `dragMoveX` so the user can move purely horizontally,
    /// purely vertically, or diagonally.
    @State private var dragMoveY: CGFloat = 0

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
                        onChanged: { translation in
                            guard recorder.isSelected else { return }
                            // Horizontal: clamped so the track
                            // can't slide past timeline 0.
                            let minDx = -CGFloat(recorder.trackStartSec)
                                * pixelsPerSecond
                            dragMoveX = max(minDx, translation.x)
                            // Vertical: clamped so the track can't
                            // ride up into the ruler area (row 0 is
                            // the topmost valid lane).
                            let minDy = -CGFloat(recorder.trackRow)
                                * TrackView.stackedRowHeight
                            dragMoveY = max(minDy, translation.y)
                        },
                        onEnded: { _ in
                            defer {
                                dragMoveX = 0
                                dragMoveY = 0
                            }
                            guard recorder.isSelected else { return }

                            // Commit horizontal motion as a
                            // trackStartSec delta.
                            let deltaSec = TimeInterval(
                                dragMoveX / pixelsPerSecond)
                            recorder.setTrackStartSec(
                                recorder.trackStartSec + deltaSec)

                            // Commit vertical motion by snapping to
                            // the nearest row.  Half-row threshold
                            // so a small drag stays in the current
                            // row; a half-row or more jumps lanes.
                            let rowDelta = Int(
                                (dragMoveY / TrackView.stackedRowHeight)
                                    .rounded())
                            let newRow = max(
                                0, recorder.trackRow + rowDelta)
                            recorder.trackRow = newRow
                        }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .overlay {
                    if recorder.isSelected {
                        selectionFrame
                    }
                }
                .offset(
                    x: CGFloat(recorder.trackStartSec) * pixelsPerSecond
                       + dragMoveX
                       + dragLeftResizeX,
                    y: CGFloat(recorder.trackRow)
                       * TrackView.stackedRowHeight
                       + dragMoveY
                )
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
        // (capsule center sits ON the selection edge).  Offset
        // values are -16 / +16 to recenter the capsule now that
        // the handle's outer frame is 32 wide (was 4) — the visible
        // capsule stays in the exact same place as before.
        .overlay(alignment: .leading) {
            handle(side: .left).offset(x: -16)
        }
        .overlay(alignment: .trailing) {
            handle(side: .right).offset(x: 16)
        }
    }

    private enum HandleSide { case left, right }

    /// A small vertical capsule that the user drags to resize the
    /// track from one edge.  The visible capsule is 4×32, but it
    /// sits inside a 32×60 outer frame which is the actual hit-test
    /// area — same comfortable hit zone as before, just expressed
    /// as a real frame size now, because UIKit's pan recognizer
    /// only hit-tests inside its own UIView bounds.  Pan gesture
    /// is the same `UIKitDragGesture` wrapper the body-drag uses;
    /// keeping both edge resizes on UIKit is what kept the drag
    /// smooth originally and re-applies the same fix here.
    private func handle(side: HandleSide) -> some View {
        Capsule()
            .fill(Color.black)
            .overlay(
                Capsule().stroke(.white, lineWidth: 1)
            )
            .frame(width: 4, height: 32)
            .frame(width: 32, height: 60)
            .contentShape(Rectangle())
            .overlay {
                UIKitDragGesture(
                    onTap: nil,
                    onChanged: { translation in
                        let tx = translation.x
                        let baseStartPx = CGFloat(recorder.trackStartSec)
                            * pixelsPerSecond
                        let baseWidthPx = CGFloat(recorder.recordedDuration)
                            * pixelsPerSecond
                        let minWidthPx  = CGFloat(0.5) * pixelsPerSecond

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
                    },
                    onEnded: { _ in
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
                )
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
