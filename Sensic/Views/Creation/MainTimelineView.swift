//
//  MainTimelineView.swift
//  Sensic
//
//  Created by Bushra Hatim Alhejaili on 19/05/2026.
//

//  Workspace › Creation
//  Main Timeline Area — Adaptive Ruler, Horizontal Zoom, Dynamic Grid,
//  and a smooth draggable Playhead.
//
//  This component has NO background of its own.
//
//  Why dragging is smooth
//  ----------------------
//  • The playhead position lives in an @Observable model. Only the
//    small `TLPlayheadLayer` child reads it, so a drag re-renders
//    ONLY that child — the parent body, ScrollView and Canvas are
//    never invalidated.
//  • The playhead is rendered OUTSIDE the timeline's
//    `.compositingGroup()`, so scrubbing never re-rasterizes the
//    heavy composited timeline buffer.
//  • The ruler/grid Canvas is an Equatable subview; it redraws only
//    on zoom or scroll.
//


import SwiftUI

// MARK: - Layout constants

private enum TLLayout {
    static let containerWidth: CGFloat  = 402
    static let containerHeight: CGFloat = 349
    static let containerRadius: CGFloat = 15

    static let topBarWidth: CGFloat  = 402
    static let topBarHeight: CGFloat = 25

    static let innerStripWidth: CGFloat  = 380
    static let innerStripHeight: CGFloat = 15

    static let rulerLeadingInset: CGFloat = 0.5
    static let rulerTopInset: CGFloat     = 3
    static let numberFontSize: CGFloat    = 10
    static let numberGap: CGFloat         = 2

    static let beatsPerBar: Int = 4
    static let totalBars: Int   = 1000

    static let tickWeight: CGFloat       = 1
    static let tickLabeledBar: CGFloat   = 25
    static let tickBar: CGFloat          = 10
    static let tickBeat: CGFloat         = 6
    static let tickSubdivision: CGFloat  = 4

    static let gridWeight: CGFloat = 1
    static var gridLength: CGFloat { containerHeight - topBarHeight }

    static let playheadWeight: CGFloat       = 1
    static var playheadLength: CGFloat { gridLength }
    static let playheadHandleWidth: CGFloat  = 11
    static let playheadHandleHeight: CGFloat = 12
    static let playheadHitPadding: CGFloat   = 10

    static let minPixelsPerBar: CGFloat     = 12
    static let maxPixelsPerBar: CGFloat     = 1200
    static let defaultPixelsPerBar: CGFloat = 20
}

// MARK: - Adaptive scale + metrics

private struct TLScale {
    var labelStride: Int
    var tickStepBeats: Double
    var gridStepBeats: Double
}

private struct TLMetrics: Equatable {
    let pixelsPerBar: CGFloat

    var pixelsPerBeat: CGFloat {
        pixelsPerBar / CGFloat(TLLayout.beatsPerBar)
    }
    func x(forBeat beat: Double) -> CGFloat {
        TLLayout.rulerLeadingInset + CGFloat(beat) * pixelsPerBeat
    }
    func beat(forX xPos: CGFloat) -> Double {
        Double(max(0, xPos - TLLayout.rulerLeadingInset) / pixelsPerBeat)
    }
    var totalBeats: Double {
        Double(TLLayout.totalBars * TLLayout.beatsPerBar)
    }
    var contentWidth: CGFloat {
        x(forBeat: totalBeats) + pixelsPerBar
    }
    var scale: TLScale {
        let bpb = Double(TLLayout.beatsPerBar)
        switch pixelsPerBar {
        case ..<80:
            return TLScale(labelStride: 4, tickStepBeats: 1,
                           gridStepBeats: bpb)
        case 80..<160:
            return TLScale(labelStride: 2, tickStepBeats: 1,
                           gridStepBeats: bpb / 2)
        case 160..<320:
            return TLScale(labelStride: 1, tickStepBeats: 1,
                           gridStepBeats: 1)
        case 320..<640:
            return TLScale(labelStride: 1, tickStepBeats: 0.5,
                           gridStepBeats: 0.5)
        default:
            return TLScale(labelStride: 1, tickStepBeats: 0.25,
                           gridStepBeats: 0.25)
        }
    }
}

// MARK: - Playhead model (only the playhead child observes this)

@Observable
private final class TLPlayheadModel {
    var beat: Double = 0
}

// MARK: - Grid canvas (Equatable → no redraw during scrub)

private struct TLGridCanvas: View, Equatable {
    let pixelsPerBar: CGFloat
    let scrollOffsetX: CGFloat
    let visibleWidth: CGFloat
    let tickColor: Color
    let gridColor: Color

    static func == (l: TLGridCanvas, r: TLGridCanvas) -> Bool {
        l.pixelsPerBar == r.pixelsPerBar &&
        l.scrollOffsetX == r.scrollOffsetX &&
        l.visibleWidth == r.visibleWidth
    }

    var body: some View {
        let m = TLMetrics(pixelsPerBar: pixelsPerBar)
        let s = m.scale
        let bpb = Double(TLLayout.beatsPerBar)

        let margin = pixelsPerBar
        let firstBeat = max(0, m.beat(forX: scrollOffsetX - margin))
        let lastBeat  = min(m.totalBeats,
                            m.beat(forX: scrollOffsetX
                                   + visibleWidth + margin))

        return Canvas { context, _ in
            let topBar     = TLLayout.topBarHeight
            let gridBottom = topBar + TLLayout.gridLength
            let tw = TLLayout.tickWeight
            let gw = TLLayout.gridWeight

            var g = (firstBeat / s.gridStepBeats).rounded(.down)
            while g * s.gridStepBeats <= lastBeat {
                let bp = g * s.gridStepBeats
                let gx = m.x(forBeat: bp)
                context.fill(
                    Path(CGRect(x: gx - gw / 2, y: topBar,
                                width: gw,
                                height: gridBottom - topBar)),
                    with: .color(gridColor))
                g += 1
            }

            var t = (firstBeat / s.tickStepBeats).rounded(.down)
            while t * s.tickStepBeats <= lastBeat {
                let bp = t * s.tickStepBeats
                t += 1
                let tx = m.x(forBeat: bp)

                let onBar  = bp.truncatingRemainder(
                    dividingBy: bpb) == 0
                let onBeat = bp.truncatingRemainder(
                    dividingBy: 1) == 0
                let barIndex = Int(bp / bpb)
                let labeled = onBar && barIndex % s.labelStride == 0

                let len: CGFloat
                if labeled     { len = TLLayout.tickLabeledBar }
                else if onBar  { len = TLLayout.tickBar }
                else if onBeat { len = TLLayout.tickBeat }
                else           { len = TLLayout.tickSubdivision }

                context.fill(
                    Path(CGRect(x: tx - tw / 2, y: topBar - len,
                                width: tw, height: len)),
                    with: .color(tickColor))

                if labeled {
                    let label = Text("\(barIndex + 1)")
                        .font(.system(size: TLLayout.numberFontSize,
                                      weight: .regular))
                        .foregroundStyle(.white)
                    context.draw(
                        label,
                        at: CGPoint(
                            x: tx + tw / 2 + TLLayout.numberGap,
                            y: TLLayout.rulerTopInset),
                        anchor: .topLeading)
                }
            }
        }
        .frame(width: m.contentWidth,
               height: TLLayout.containerHeight)
    }
}

// MARK: - Playhead handle shape

private struct TLPlayheadHandleShape: Shape {
    func path(in rect: CGRect) -> Path {
        let r: CGFloat = 3
        let pointDepth = rect.height * 0.42
        let bodyBottom = rect.maxY - pointDepth

        var p = Path()
        p.move(to: CGPoint(x: rect.minX + r, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + r),
                       control: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: bodyBottom - r))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - r, y: bodyBottom),
                       control: CGPoint(x: rect.maxX, y: bodyBottom))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + r, y: bodyBottom))
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: bodyBottom - r),
                       control: CGPoint(x: rect.minX, y: bodyBottom))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
        p.addQuadCurve(to: CGPoint(x: rect.minX + r, y: rect.minY),
                       control: CGPoint(x: rect.minX, y: rect.minY))
        p.closeSubpath()
        return p
    }
}

// MARK: - Playhead layer (self-contained; only this re-renders on drag)

private struct TLPlayheadLayer: View {
    @Bindable var model: TLPlayheadModel
    let metrics: TLMetrics
    let scrollOffsetX: CGFloat
    let stripWidth: CGFloat
    let lineColor: Color
    let fillColor: Color

    /// Live beat delta during a drag.  Plain `@State` because the
    /// drag is now a UIKit `UIPanGestureRecognizer` (via
    /// `UIKitDragGesture`) — UIKit recognizers have no
    /// auto-resetting equivalent of `@GestureState`, so we reset
    /// this manually in the gesture's `onEnded`.  We still never
    /// write `model.beat` mid-drag; only on `onEnded`, so the
    /// @Observable model doesn't broadcast at 60Hz.
    @State private var dragBeatDelta: Double = 0

    var body: some View {
        let handleW = TLLayout.playheadHandleWidth
        let handleH = TLLayout.playheadHandleHeight
        let pad     = TLLayout.playheadHitPadding
        // Visual position = committed beat + live drag delta.  During
        // drag, model.beat is stable and only `dragBeatDelta` moves,
        // which is what keeps the playhead pixel-locked to the finger.
        let visualBeat = model.beat + dragBeatDelta
        let screenX = metrics.x(forBeat: visualBeat) - scrollOffsetX

        return ZStack(alignment: .topLeading) {
            ZStack(alignment: .top) {
                Rectangle()
                    .fill(lineColor)
                    .frame(width: TLLayout.playheadWeight,
                           height: TLLayout.playheadLength)
                    .offset(y: TLLayout.topBarHeight)
                    .allowsHitTesting(false)

                TLPlayheadHandleShape()
                    .fill(fillColor)
                    .overlay(
                        TLPlayheadHandleShape()
                            .stroke(lineColor, lineWidth: 1)
                    )
                    .frame(width: handleW, height: handleH)
                    .padding(pad)
                    .contentShape(Rectangle())
                    .overlay {
                        UIKitDragGesture(
                            onChanged: { tx in
                                let rawDelta = Double(
                                    tx / metrics.pixelsPerBeat)
                                let target = model.beat + rawDelta
                                let clamped = min(
                                    max(0, target),
                                    metrics.totalBeats)
                                dragBeatDelta = clamped - model.beat
                            },
                            onEnded: { tx in
                                let rawDelta = Double(
                                    tx / metrics.pixelsPerBeat)
                                let target = model.beat + rawDelta
                                model.beat = min(
                                    max(0, target),
                                    metrics.totalBeats)
                                dragBeatDelta = 0
                            }
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .offset(y: TLLayout.topBarHeight - handleH - pad)
            }
            .frame(width: handleW,
                   height: TLLayout.containerHeight,
                   alignment: .top)
            .offset(x: screenX - handleW / 2)
        }
        .frame(width: stripWidth,
               height: TLLayout.containerHeight,
               alignment: .topLeading)
        .clipped()
        // Strip animation from every transaction reaching this
        // layer.  Same reason as TrackOverlay — the .offset that
        // positions the playhead must snap to each gesture tick,
        // never interpolate.
        .transaction { transaction in
            transaction.animation = nil
            transaction.disablesAnimations = true
        }
    }
}

// MARK: - Main Timeline View

struct MainTimelineView: View {

    /// Recording session state — owns the captured notes and drives
    /// the playhead during recording / playback. The parent body
    /// does NOT observe it (kept as a `let`) so the heavy timeline
    /// body doesn't re-render at 60Hz; only the `TrackOverlay`
    /// subview observes the recorder and re-renders on each tick.
    let recorder: TrackRecorder

    private let tickColor = Color.indigoBlue
    private let gridColor = Color.gray.opacity(0.2)
    private let playheadLineColor = Color.lavender    // asset "Lavender"
    private let playheadFillColor = Color.mainPurple  // asset "MainPurple"

    @State private var pixelsPerBar: CGFloat = TLLayout.defaultPixelsPerBar
    @State private var zoomStartPPB: CGFloat?
    @State private var zoomFocalBeat: Double = 0
    @State private var scrollPosition = ScrollPosition(edge: .leading)
    @State private var scrollOffsetX: CGFloat = 0
    @State private var viewportW: CGFloat = 0

    // Parent never reads `playhead.beat`, so dragging it does NOT
    // invalidate this body.
    @State private var playhead = TLPlayheadModel()

    // MARK: Edit-menu state

    /// Tracks created by Paste actions.  Each is a self-contained
    /// `TrackRecorder` populated from the clipboard snapshot — they
    /// share no state with the primary recorder.
    @State private var pastedTracks: [TrackRecorder] = []

    /// What's on the clipboard (set by Copy, consumed by Paste).
    @State private var clipboard: TrackSnapshot?

    /// Drives the iOS edit-menu presentation.  Nil = no menu;
    /// non-nil = present a menu with these contents at this point.
    @State private var menuPresentation: MenuPresentation?

    /// Which track the next Rename alert should write to.  Held
    /// across the lifetime of the alert (which is dismissed by the
    /// system once a button is tapped).
    @State private var renameTarget: TrackRecorder?
    @State private var renameText: String = ""
    @State private var showRenameAlert: Bool = false

    /// What the edit menu is currently targeting — either a
    /// specific track (Copy/Paste/Delete/Rename apply to it) or
    /// an empty point on the timeline (only Paste applies).
    enum MenuTarget {
        case track(TrackRecorder)
        case emptySpace(trackStartSec: TimeInterval)
    }

    /// Bundles target + anchor point so a single `@State` controls
    /// both whether the menu is up and where it appears.
    struct MenuPresentation {
        let target: MenuTarget
        let sourcePoint: CGPoint
    }

    private var metrics: TLMetrics {
        TLMetrics(pixelsPerBar: pixelsPerBar)
    }
    private var stripWidth: CGFloat {
        scrollOffsetX > 0 ? TLLayout.containerWidth
                          : TLLayout.innerStripWidth
    }

    private func spaceBlueShadowed<S: Shape>(_ shape: S) -> some View {
        shape
            .fill(Color("SpaceBlue"))
            .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 4)
    }

    private var scrollableGrid: some View {
        let pixelsPerBeat = pixelsPerBar / CGFloat(TLLayout.beatsPerBar)
        let pixelsPerSecond = pixelsPerBeat * CGFloat(recorder.bpm / 60)

        return ScrollView(.horizontal, showsIndicators: false) {
            ZStack(alignment: .topLeading) {
                TLGridCanvas(pixelsPerBar: pixelsPerBar,
                             scrollOffsetX: scrollOffsetX,
                             visibleWidth: stripWidth,
                             tickColor: tickColor,
                             gridColor: gridColor)
                    .equatable()

                // Empty-space tap catcher.  Only present when
                // there's something on the clipboard — otherwise
                // there'd be nothing to paste, and we don't want
                // to swallow taps that would scroll the canvas.
                // Sits BELOW the track overlays so tracks still
                // get first crack at their own taps.
                if clipboard != nil {
                    Color.clear
                        .contentShape(Rectangle())
                        .frame(maxWidth: .infinity,
                               maxHeight: .infinity)
                        .onTapGesture(coordinateSpace: .local) { loc in
                            handleEmptySpaceTap(
                                at: loc,
                                pixelsPerSecond: pixelsPerSecond)
                        }
                }

                // Primary recording track.
                TrackOverlay(
                    recorder: recorder,
                    pixelsPerSecond: pixelsPerSecond,
                    onRequestEditMenu: { loc, target in
                        showEditMenu(
                            at: loc,
                            for: target,
                            pixelsPerSecond: pixelsPerSecond)
                    })
                    .offset(x: TLLayout.rulerLeadingInset,
                            y: TLLayout.topBarHeight + 2)

                // Pasted tracks — each is rendered exactly like the
                // primary, with its own selection / drag / edit-menu
                // behavior.
                ForEach(pastedTracks) { paste in
                    TrackOverlay(
                        recorder: paste,
                        pixelsPerSecond: pixelsPerSecond,
                        onRequestEditMenu: { loc, target in
                            showEditMenu(
                                at: loc,
                                for: target,
                                pixelsPerSecond: pixelsPerSecond)
                        })
                        .offset(x: TLLayout.rulerLeadingInset,
                                y: TLLayout.topBarHeight + 2)
                }
            }
        }
        .scrollPosition($scrollPosition)
        .frame(width: stripWidth, height: TLLayout.containerHeight)
        .clipped()
        .onScrollGeometryChange(for: CGRect.self) { geo in
            CGRect(x: geo.contentOffset.x, y: 0,
                   width: geo.containerSize.width, height: 0)
        } action: { _, new in
            scrollOffsetX = max(0, new.minX)
            viewportW = new.width
        }
        .simultaneousGesture(zoomGesture)
        // Edit-menu host.  Sits OUTSIDE the ScrollView's content so
        // its `sourcePoint` is in screen-stable coordinates that
        // don't drift as the user scrolls.  Touches pass straight
        // through it (`PassthroughHostView` returns nil from
        // hitTest) so it doesn't interfere with anything below.
        .overlay(alignment: .topLeading) {
            EditMenuPresenter(
                isPresented: Binding(
                    get: { menuPresentation != nil },
                    set: { if !$0 { menuPresentation = nil } }
                ),
                sourcePoint: menuPresentation?.sourcePoint ?? .zero,
                actions: editMenuActions,
                onAction: handleMenuAction
            )
            .frame(width: stripWidth,
                   height: TLLayout.containerHeight)
        }
        // Rename alert.  Driven by `showRenameAlert` so the alert's
        // own lifecycle can dismiss it without us having to mirror
        // dismissal through any other state.
        .alert("Rename Track", isPresented: $showRenameAlert) {
            TextField("Track name", text: $renameText)
            Button("Cancel", role: .cancel) {
                renameTarget = nil
            }
            Button("Rename") {
                renameTarget?.setTrackName(renameText)
                renameTarget = nil
            }
        } message: {
            Text("Enter a new name for this track.")
        }
        // Mirror the primary recorder's playback transport onto
        // every pasted track.  Pasted recorders aren't owned by the
        // parent, so they don't get .playTapped()/.stopTapped()
        // calls from the transport bar — we proxy them here so all
        // tracks on the timeline play and stop together.
        .onReceive(recorder.$isPlayingBack) { isPlaying in
            if isPlaying {
                for track in pastedTracks where !track.isPlayingBack {
                    track.playTapped()
                }
            } else {
                for track in pastedTracks where track.isPlayingBack {
                    track.stopTapped()
                }
            }
        }
    }

    // MARK: Edit-menu plumbing

    /// Actions for whatever the menu is currently targeting.  A
    /// tapped track gets the full Copy/Paste/Edit/Delete/Rename
    /// set; an empty-space tap gets just Paste.
    private var editMenuActions: [EditMenuAction] {
        guard let target = menuPresentation?.target else { return [] }
        switch target {
        case .track:
            return [
                EditMenuAction(id: "copy",   title: "Copy"),
                EditMenuAction(id: "paste",  title: "Paste"),
                EditMenuAction(id: "edit",   title: "Edit"),
                EditMenuAction(id: "delete", title: "Delete",
                               isDestructive: true),
                EditMenuAction(id: "rename", title: "Rename"),
            ]
        case .emptySpace:
            return [
                EditMenuAction(id: "paste",  title: "Paste"),
            ]
        }
    }

    /// Convert a tap inside a TrackOverlay's local coordinate space
    /// into the timeline's coordinate space, then to the screen-
    /// stable space the EditMenuPresenter overlay lives in.
    /// (Subtracting `scrollOffsetX` cancels out the scroll so the
    /// menu sits over the finger no matter where in the timeline
    /// the user tapped.)
    private func showEditMenu(at trackLocalPoint: CGPoint,
                              for target: TrackRecorder,
                              pixelsPerSecond: CGFloat) {
        let trackOffsetX = CGFloat(target.trackStartSec)
            * pixelsPerSecond
        let timelineX = TLLayout.rulerLeadingInset
            + trackOffsetX + trackLocalPoint.x
        let timelineY = TLLayout.topBarHeight + 2
            + trackLocalPoint.y
        let sourcePoint = CGPoint(
            x: timelineX - scrollOffsetX,
            y: timelineY)
        menuPresentation = MenuPresentation(
            target: .track(target),
            sourcePoint: sourcePoint)
    }

    /// Handler for taps on empty timeline space — only invoked
    /// when there's something on the clipboard, so the menu we
    /// raise always offers Paste.
    private func handleEmptySpaceTap(at scrollLocalPoint: CGPoint,
                                     pixelsPerSecond: CGFloat) {
        let timelineX = scrollLocalPoint.x - TLLayout.rulerLeadingInset
        let trackStartSec = TimeInterval(
            max(0, timelineX / pixelsPerSecond))
        let sourcePoint = CGPoint(
            x: scrollLocalPoint.x - scrollOffsetX,
            y: scrollLocalPoint.y)
        menuPresentation = MenuPresentation(
            target: .emptySpace(trackStartSec: trackStartSec),
            sourcePoint: sourcePoint)
    }

    /// Single entry point for every menu action.  Switches on the
    /// (action-id, target) pair so each combo's logic is in one
    /// readable place.  Always dismisses the menu at the end.
    private func handleMenuAction(_ actionId: String) {
        defer { menuPresentation = nil }
        guard let presentation = menuPresentation else { return }

        switch (actionId, presentation.target) {

        case ("copy", .track(let recorder)):
            clipboard = TrackSnapshot(
                notes: recorder.notes,
                duration: recorder.recordedDuration,
                name: recorder.trackName)

        case ("paste", let target):
            guard let snap = clipboard else { return }
            let startSec: TimeInterval
            switch target {
            case .track(let recorder):
                // Pasting onto an existing track drops the copy
                // immediately after that track.
                startSec = recorder.trackStartSec
                    + recorder.recordedDuration
            case .emptySpace(let sec):
                startSec = sec
            }
            let newTrack = TrackRecorder()
            newTrack.loadSnapshot(snap, atStartSec: startSec)
            // Share the primary recorder's audio destination so the
            // copy actually makes sound during playback.  bind(to:)
            // also sets up an activeNotes sink, but its handler
            // guards on `isRecording`, so a non-recording pasted
            // track will never capture stray key presses.
            if let vm = recorder.audioOutput {
                newTrack.bind(to: vm)
            }
            pastedTracks.append(newTrack)
            // Register the paste with the primary's undo system so
            // the undo button can reverse it.  We use softDelete
            // (not array removal) so the same TrackRecorder
            // instance stays around for redo.
            recorder.pushUndoableAction(
                TrackRecorder.UndoableAction(
                    undo: { newTrack.deleteTrack() },
                    redo: { newTrack.undelete()    }
                )
            )

        case ("delete", .track(let track)):
            // Soft-delete: the track's data survives so an undo can
            // bring it back.  Routed through the primary's undo
            // stack so the same button handles both note-level and
            // track-level undo.
            track.deleteTrack()
            recorder.pushUndoableAction(
                TrackRecorder.UndoableAction(
                    undo: { track.undelete()    },
                    redo: { track.deleteTrack() }
                )
            )

        case ("rename", .track(let recorder)):
            renameTarget    = recorder
            renameText      = recorder.trackName
            showRenameAlert = true

        case ("edit", _):
            // Intentionally a no-op for now — Edit is a placeholder
            // until we know what it should open.
            break

        default:
            break
        }
    }

    private var zoomGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                if zoomStartPPB == nil {
                    zoomStartPPB = pixelsPerBar
                    let centreX = scrollOffsetX + viewportW / 2
                    zoomFocalBeat = metrics.beat(forX: centreX)
                }
                let base = zoomStartPPB ?? pixelsPerBar
                pixelsPerBar = min(
                    max(base * value.magnification,
                        TLLayout.minPixelsPerBar),
                    TLLayout.maxPixelsPerBar)

                let targetX = metrics.x(forBeat: zoomFocalBeat)
                    - viewportW / 2
                scrollPosition.scrollTo(x: max(0, targetX))
            }
            .onEnded { _ in zoomStartPPB = nil }
    }

    var body: some View {
        ZStack(alignment: .topLeading) {

            // ---- Timeline (heavy) — inside the compositing group ----
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: TLLayout.containerRadius)
                    .fill(Color("TransparentSpaceBlue"))
                    .frame(width: TLLayout.containerWidth,
                           height: TLLayout.containerHeight)

                spaceBlueShadowed(
                    UnevenRoundedRectangle(
                        topLeadingRadius: TLLayout.containerRadius,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: TLLayout.containerRadius)
                )
                .frame(width: TLLayout.topBarWidth,
                       height: TLLayout.topBarHeight)

                spaceBlueShadowed(Rectangle())
                    .frame(width: stripWidth,
                           height: TLLayout.innerStripHeight)
                    .frame(width: TLLayout.containerWidth,
                           alignment: .topTrailing)

                scrollableGrid
                    .frame(width: TLLayout.containerWidth,
                           height: TLLayout.containerHeight,
                           alignment: .topTrailing)
            }
            .frame(width: TLLayout.containerWidth,
                   height: TLLayout.containerHeight)
            .compositingGroup()
            .clipShape(RoundedRectangle(
                cornerRadius: TLLayout.containerRadius))

            // ---- Playhead (light) — OUTSIDE the compositing group ----
            TLPlayheadLayer(model: playhead,
                            metrics: metrics,
                            scrollOffsetX: scrollOffsetX,
                            stripWidth: stripWidth,
                            lineColor: playheadLineColor,
                            fillColor: playheadFillColor)
                .frame(width: TLLayout.containerWidth,
                       height: TLLayout.containerHeight,
                       alignment: .topTrailing)
                .clipShape(RoundedRectangle(
                    cornerRadius: TLLayout.containerRadius))
        }
        .frame(width: TLLayout.containerWidth,
               height: TLLayout.containerHeight)
        .onReceive(recorder.$playheadSeconds) { seconds in
            // While the recorder is advancing the playhead, push
            // the converted beat value into the timeline's model.
            // This subscription doesn't invalidate the body — only
            // the small TLPlayheadLayer child re-renders on each
            // model update.
            if recorder.isAdvancing {
                let beats = seconds * recorder.bpm / 60
                playhead.beat = min(beats, metrics.totalBeats)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    MainTimelineView(recorder: TrackRecorder())
        .padding()
        .preferredColorScheme(.dark)
}
