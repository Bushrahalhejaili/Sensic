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
//  Drop this in: Views/Creation/
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

    @State private var dragStartBeat: Double?

    private var drag: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if dragStartBeat == nil { dragStartBeat = model.beat }
                let step = metrics.scale.tickStepBeats
                let delta = Double(
                    value.translation.width / metrics.pixelsPerBeat)
                let raw = (dragStartBeat ?? model.beat) + delta
                let snapped = (raw / step).rounded() * step
                model.beat = min(max(0, snapped), metrics.totalBeats)
            }
            .onEnded { _ in dragStartBeat = nil }
    }

    var body: some View {
        let handleW = TLLayout.playheadHandleWidth
        let handleH = TLLayout.playheadHandleHeight
        let pad     = TLLayout.playheadHitPadding
        let screenX = metrics.x(forBeat: model.beat) - scrollOffsetX

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
                    .highPriorityGesture(drag)
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

                TrackOverlay(recorder: recorder,
                             pixelsPerSecond: pixelsPerSecond)
                    .offset(x: TLLayout.rulerLeadingInset,
                            y: TLLayout.topBarHeight + 2)
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
                    .animation(.easeOut(duration: 0.2),
                               value: stripWidth)

                scrollableGrid
                    .frame(width: TLLayout.containerWidth,
                           height: TLLayout.containerHeight,
                           alignment: .topTrailing)
                    .animation(.easeOut(duration: 0.2),
                               value: stripWidth)
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
                .animation(.easeOut(duration: 0.2), value: stripWidth)
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
