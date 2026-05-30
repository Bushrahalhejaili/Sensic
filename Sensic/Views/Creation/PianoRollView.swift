//
//  PianoRollView.swift
//  Sensic
//
//  Created by Bushra Hatim Alhejaili on 26/05/2026.
//


//
//  PianoRollView.swift
//  Sensic
//
//  Workspace › Creation › Edit Sheet
//
//  The FULL sheet content — when CreationView opens the edit
//  sheet, this view fills the sheet detent.  The rounded
//  card chrome, the head strip, the vertical piano, the
//  2D-scrolling lanes, and the note rectangles — all of it
//  lives here, so CreationView just presents PianoRollView
//  directly via `.sheet(…)` with the detent and
//  drag-indicator modifiers attached to it.
//
//  Layout (matches the Figma — "Before any scrolling" and
//  "After scrolling left and right and up and down"):
//
//    ┌─ card (no fill — empty gaps show through) ───────┐
//    │  ┌─ HEAD ───────────────────────────────────┐    │
//    │  │ outer rect: full width × 25, SpaceBlue,  │    │
//    │  │   rounded top, drop shadow                │    │
//    │  │ inner rect: stripWidth × 15, SpaceBlue,   │    │
//    │  │   right-aligned, same shadow.             │    │
//    │  ├─ PIANO ────┬─ LANES ────────────────────┤    │
//    │  │ 56pt wide  │ SpaceBlue (white) +        │    │
//    │  │ 88 keys    │ IndigoBlue (black) striped │    │
//    │  │            │ lanes + note rects, 2D     │    │
//    │  └────────────┴────────────────────────────┘    │
//    └──────────────────────────────────────────────────┘
//
//  Lanes are NOT a solid block — each is a stripe centered
//  on its key (SpaceBlue 14pt on whites, IndigoBlue 12pt on
//  blacks).  Between stripes the background is transparent,
//  so the sheet's own dark backdrop shows through as the
//  "empty areas" from the Figma.  88 stripes total: 52
//  white + 36 black.
//
//  Three independent jobs:
//    1. Drive `recorder.audioOutput` so each piano key is
//       press-to-play (no recording — this sheet only plays
//       the sound of the keys, it never adds notes).
//    2. Render the recorder's notes as draggable +
//       right-edge-resizable rectangles on the lanes.
//    3. Show the head + the rounded card chrome — i.e.
//       BE the sheet's content end-to-end.
//
//  Scroll model (one vertical scroll + a nested horizontal):
//    The whole grid lives in a SINGLE vertical ScrollView.
//    Inside it, a ZStack: the lanes span the FULL width and
//    scroll HORIZONTALLY (time); the frozen piano column is
//    overlaid on top of their leading edge.
//      • Pitch (up/down): the outer vertical scroll moves the
//        ZStack — piano and lanes together, automatically, no
//        manual offset mirror.  A single-axis vertical scroll
//        always rests at its TOP and reaches its full content,
//        so it opens at C8 and scrolls all the way to A0.
//        (The old 2-axis scroll opened CENTERED ≈ D5 and
//        wouldn't reach the ends — that was the bug.)
//      • Time (left/right): the nested horizontal scroll moves
//        only the lanes; the piano column stays frozen on top.
//        Its `.onScrollGeometryChange` feeds `scrollOffset.x`,
//        and the head reads that to swap `stripWidth` from
//        `containerW - 22` to `containerW` (the notch-closing
//        cue MainTimelineView uses).
//      • Because the lanes run the FULL width, they pass
//        UNDERNEATH the keys — no gap between keys and lanes.
//        The leftmost `whiteKeyW` of lane content is hidden
//        behind the opaque keys; notes use `leftMargin =
//        whiteKeyW` so they start just past the keys.
//      • The head is an overlay pinned to the top, OUTSIDE the
//        vertical scroll, so it never pans up/down.
//
//    The scroll content has a `topInset`-tall transparent top
//    spacer (`contentH = topInset + totalH`); the piano column
//    uses the SAME spacer + the SAME per-slot heights, so the
//    two stay locked together row-for-row.
//
//  Drop this in: Views/Creation/
//

import SwiftUI
import UIKit

// MARK: - PianoRollView

struct PianoRollView: View {

    @ObservedObject var recorder: TrackRecorder

    /// Live scroll offset of the lanes ScrollView, mirrored
    /// from `.onScrollGeometryChange`.  Drives the visual
    /// `stripWidth` swap (`x > 0` → notch closes).  Only the
    /// `.x` field is used now — vertical sync is handled by
    /// the shared vertical ScrollView, so there's no `-y`
    /// mirror onto the piano column anymore.
    @State private var scrollOffset: CGPoint = .zero

    // MARK: Horizontal zoom + scroll
    //
    // Independent of the main timeline (its own zoom/scroll
    // state), but mirrors the timeline's `pixelsPerBar` model
    // so the grid + roller line up musically — a note at bar 3
    // here sits at bar 3 on the timeline.

    /// Horizontal zoom. Bigger = more pixels per bar.
    @State private var pixelsPerBar: CGFloat = TLLayout.defaultPixelsPerBar
    /// Captured at the start of a pinch so we scale from a fixed
    /// base; nil when not zooming.
    @State private var zoomStartPPB: CGFloat?
    /// Beat under the viewport centre when a pinch begins — we
    /// re-anchor the scroll to keep it put (focal-locked zoom).
    @State private var zoomFocalBeat: Double = 0
    /// Drives the programmatic horizontal scroll during the
    /// zoom re-anchor.
    @State private var hScrollPosition = ScrollPosition(edge: .leading)
    /// Live width of the horizontal viewport (for the focal calc).
    @State private var viewportW: CGFloat = 0

    /// Beat ↔ x model for the roll's horizontal axis.
    private var metrics: PRMetrics {
        PRMetrics(pixelsPerBar: pixelsPerBar)
    }

    /// Colours, matched to the main timeline.
    private let tickColor = Color("IndigoBlue")
    private let gridColor = Color.gray.opacity(0.2)

    // MARK: Edit menu + clipboard (Apple UIEditMenuInteraction,
    //       reusing EditMenuPresenter / EditMenuAction from
    //       TrackView.swift — same look as the main timeline)

    /// What the edit menu is currently targeting — a specific note
    /// (Copy / Paste / Delete) or an empty point on the timeline
    /// (Add, plus Paste when something's on the clipboard).  The
    /// empty-space case carries the snapped pitch + beat so the
    /// Add/Paste actions know where to place the note.
    private enum PRMenuTarget {
        case note(RecordedNote)
        case emptySpace(beat: Double, midi: UInt8)
    }

    /// Bundles the target with the screen-space anchor so a single
    /// `@State` controls both whether the menu is up and where it
    /// appears.
    private struct PRMenuPresentation {
        let target: PRMenuTarget
        let sourcePoint: CGPoint
    }

    @State private var menuPresentation: PRMenuPresentation?

    /// A copied note (Copy action).  Paste stamps a duplicate of
    /// its length + velocity at the tapped pitch / time.  Paste is
    /// only offered while this is non-nil.
    @State private var noteClipboard: RecordedNote?

    // MARK: 88-key audit
    //
    // A standard piano spans midi 21 (A0) to midi 108 (C8)
    // — exactly 88 keys: 52 whites + 36 blacks.  This view
    // renders ALL 88 of them; only ~12 fit on-screen at the
    // 322pt sheet detent, so the rest are reached by panning
    // the lanes ScrollView (which also pans the piano column
    // via the scroll-offset mirror in `pianoColumn`).
    fileprivate static let numWhiteKeys:      Int = 52
    fileprivate static let numBlackPositions: Int = 51

    // MARK: Layout constants — piano + lanes

    fileprivate static let whiteKeyW:    CGFloat = 56
    fileprivate static let whiteKeyH:    CGFloat = 24
    fileprivate static let blackKeyW:    CGFloat = 36
    fileprivate static let blackKeyH:    CGFloat = 12
    /// Lane VISUAL height for whites — the SpaceBlue stripe.
    /// 14pt, vertically CENTERED on the 24pt white key, so
    /// there's 5pt of empty (transparent) space above and
    /// below each lane.  That empty space is the striped /
    /// gapped look from the Figma.
    fileprivate static let whiteLaneH:   CGFloat = 14
    /// Lane VISUAL height for blacks — the IndigoBlue stripe,
    /// 12pt, sitting on the boundary between two white lanes.
    fileprivate static let blackLaneH:   CGFloat = 12
    /// Height of the note rectangle drawn on top of a lane.
    /// Equals the lane height on both white (14) and black
    /// (12), so a note exactly covers its lane stripe.
    fileprivate static let whiteNoteH:   CGFloat = 14
    fileprivate static let blackNoteH:   CGFloat = 12
    fileprivate static let keyCornerR:   CGFloat = 10
    fileprivate static let whiteSpacing: CGFloat = 2

    /// Horizontal offset where the note rectangles begin
    /// inside the lanes content.  The lanes run the FULL width
    /// and the piano is overlaid on their leading edge, so the
    /// leftmost `whiteKeyW` of lane content is hidden behind
    /// the keys.  Notes therefore start at `whiteKeyW` so a
    /// time-0 note sits just past the keys; as time scrolls,
    /// notes pan left and disappear under the keys.
    fileprivate static let leftMargin: CGFloat = whiteKeyW

    /// Minimum visual width for a note rectangle, so very
    /// short notes stay grabbable.
    fileprivate static let noteDefaultW: CGFloat = 32

    // MARK: Layout constants — head + container

    /// Outer head height — the full SpaceBlue strip at the
    /// top of the card.  Matches MainTimelineView's
    /// `topBarHeight`.
    fileprivate static let headH:       CGFloat = 25
    /// Inner head strip height.  Matches MainTimelineView's
    /// `innerStripHeight`.
    fileprivate static let headInnerH:  CGFloat = 15
    /// Width of the visible left-notch — how much of the
    /// outer head rect peeks through to the LEFT of the
    /// right-aligned inner strip when at scroll origin.  Set
    /// to the piano-column width so the inner strip's left
    /// edge lines up with where the KEYS end (i.e. the inner
    /// strip sits over the LANES only), instead of running
    /// almost the full width.  Raise this to push the inner
    /// strip's left edge further right; lower it to make the
    /// inner strip longer.
    fileprivate static let notchW:      CGFloat = whiteKeyW
    /// Corner radius of the outer card AND the top corners
    /// of the head's outer rect.  They coincide at the top
    /// of the card so the head's rounded top matches the
    /// card's rounded top.
    fileprivate static let containerR:  CGFloat = 15

    /// Empty gap above the first lane/key, measured from the
    /// top of the card.  This is the single knob for the
    /// piano's vertical start position:
    ///   • `0`      → top of the piano is level with the TOP
    ///                of the head (same Y as the head). The
    ///                head strip overlays the top ~25pt, so
    ///                C8 tucks just behind it.
    ///   • `headH`  → first key sits just BELOW the head.
    /// Used by both scroll columns AND the note math, so the
    /// lanes, the keys, and the notes all move together.
    fileprivate static let topInset:    CGFloat = headH

    // MARK: Derived metrics

    fileprivate static var whiteSlotH: CGFloat {
        whiteKeyH + whiteSpacing
    }
    /// Total piano-content height = 51 slots × 26h + 1 last
    /// key × 24h = 1350pt.  (Independent of the lane stripe
    /// height — the slots are sized by the KEY, not the
    /// stripe, so the lanes and the piano column stay the
    /// same total height and scroll in lockstep.)
    fileprivate static var totalH: CGFloat {
        CGFloat(numWhiteKeys) * whiteKeyH
            + CGFloat(numBlackPositions) * whiteSpacing
    }
    /// Scroll content height = piano + the top inset spacer.
    fileprivate static var contentH: CGFloat {
        topInset + totalH
    }

    /// Width of the inner head strip — `containerW − notchW`
    /// at scroll origin (notch visible), `containerW` once
    /// `scrollOffset.x > 0` (notch closes).
    private func stripWidth(containerW: CGFloat) -> CGFloat {
        scrollOffset.x > 0
            ? containerW
            : max(0, containerW - Self.notchW)
    }

    // MARK: Black-key pattern (descending)

    /// `true` if a black key lives between the white at `i`
    /// and the next white below (`i+1`).  Descending from C,
    /// the 7-white cycle is C–B–A–G–F–E–D; the only two
    /// transitions with no black between them are C→B
    /// (cycle index 0) and F→E (cycle index 4).
    fileprivate static func hasBlackAfter(_ i: Int) -> Bool {
        let c = i % 7
        return c != 0 && c != 4
    }

    // MARK: White-key index ↔ midi

    fileprivate static let whiteSemitones: [Int] = [
        0,  // C
        1,  // B
        3,  // A
        5,  // G
        7,  // F
        8,  // E
        10, // D
    ]

    fileprivate static let whiteSemitoneToCycle: [Int: Int] = [
        0: 0, 1: 1, 3: 2, 5: 3, 7: 4, 8: 5, 10: 6,
    ]

    fileprivate static func whiteMidi(at i: Int) -> UInt8 {
        let octaveBlock = i / 7
        let pos         = i % 7
        let semitone    = whiteSemitones[pos]
        return UInt8(108 - (octaveBlock * 12 + semitone))
    }

    fileprivate static func whiteIndex(forWhiteMidi midi: UInt8) -> Int {
        let offset       = 108 - Int(midi)
        let octaveBlock  = offset / 12
        let posInOctave  = offset % 12
        return octaveBlock * 7
             + (whiteSemitoneToCycle[posInOctave] ?? 0)
    }

    fileprivate static func isBlack(_ midi: UInt8) -> Bool {
        let n = midi % 12
        return n == 1 || n == 3 || n == 6 || n == 8 || n == 10
    }

    // MARK: Y positions (in scroll-content coordinates —
    //       all returned values assume the 25pt head spacer
    //       is applied OUTSIDE these helpers)

    fileprivate static func whiteKeyY(_ i: Int) -> CGFloat {
        CGFloat(i) * whiteSlotH
    }
    /// Top Y of a white lane.  The 14pt SpaceBlue stripe is
    /// vertically centered on the 24pt key, so the lane top
    /// sits 5pt below the key top: (whiteKeyH - whiteLaneH)/2.
    fileprivate static func whiteLaneY(_ i: Int) -> CGFloat {
        whiteKeyY(i) + (whiteKeyH - whiteLaneH) / 2
    }
    fileprivate static func blackKeyY(after i: Int) -> CGFloat {
        whiteKeyY(i) + whiteKeyH + whiteSpacing / 2 - blackKeyH / 2
    }
    /// Top Y of a black lane.  `blackLaneH == blackKeyH` so
    /// the lane top equals the key top — straddling the 2pt
    /// gap between the two white lanes it sits between.
    fileprivate static func blackLaneY(after i: Int) -> CGFloat {
        blackKeyY(after: i)
    }
    fileprivate static func laneY(for midi: UInt8) -> CGFloat {
        if isBlack(midi) {
            let idx = whiteIndex(forWhiteMidi: midi + 1)
            return blackLaneY(after: idx)
        } else {
            return whiteLaneY(whiteIndex(forWhiteMidi: midi))
        }
    }

    /// Reverse-lookup: given a Y in piano-content coords
    /// (i.e. *without* the head spacer), return the midi
    /// note whose lane centre is closest.  Used by the
    /// note-rectangle body-drag to snap to a new pitch.
    fileprivate static func midi(forY y: CGFloat) -> UInt8 {
        var bestMidi: UInt8 = 60
        var bestDist: CGFloat = .infinity
        for m in UInt8(21)...UInt8(108) {
            let top    = laneY(for: m)
            let h      = isBlack(m) ? blackLaneH : whiteLaneH
            let centre = top + h / 2
            let d      = abs(y - centre)
            if d < bestDist { bestDist = d; bestMidi = m }
        }
        return bestMidi
    }

    // MARK: Pinch-to-zoom (focal-locked, horizontal only)

    /// Pinch scales `pixelsPerBar` (clamped to the timeline's
    /// range).  On gesture start it captures the beat at the
    /// viewport centre, then re-anchors the scroll every change
    /// so that beat stays under the finger — the grid, roller
    /// and notes all reflow through `metrics`, so they stay in
    /// register.  Pitch (vertical) never zooms.
    private var zoomGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                if zoomStartPPB == nil {
                    zoomStartPPB = pixelsPerBar
                    let centreX = scrollOffset.x + viewportW / 2
                    zoomFocalBeat = metrics.beat(forX: centreX)
                }
                let base = zoomStartPPB ?? pixelsPerBar
                pixelsPerBar = min(
                    max(base * value.magnification,
                        TLLayout.minPixelsPerBar),
                    TLLayout.maxPixelsPerBar)

                let targetX = metrics.x(forBeat: zoomFocalBeat)
                    - viewportW / 2
                hScrollPosition.scrollTo(x: max(0, targetX))
            }
            .onEnded { _ in zoomStartPPB = nil }
    }

    // MARK: Body

    var body: some View {
        GeometryReader { proxy in
            let containerW = proxy.size.width

            ZStack(alignment: .topLeading) {

                // The WHOLE grid lives in ONE vertical
                // ScrollView.  A single-axis vertical scroll
                // always rests at its TOP and can reach its
                // full content — which is what the old 2-axis
                // scroll wasn't doing (opened centered ≈ D5,
                // wouldn't reach the ends).
                //
                // Inside, a ZStack: the lanes span the FULL
                // width and scroll horizontally; the piano
                // column is overlaid ON TOP of their leading
                // edge.  Because the lanes run full-width, they
                // pass UNDERNEATH the keys — no gap between keys
                // and lanes (the Figma look).  The leftmost
                // `whiteKeyW` of the lanes is simply hidden
                // behind the opaque keys.  Both children are
                // `contentH` tall and ride the same vertical
                // scroll, so keys and lanes move together with
                // no manual mirroring.
                ScrollView(.vertical, showsIndicators: false) {
                    ZStack(alignment: .topLeading) {

                        // Lanes + notes — full width, horizontal
                        // scroll for time, running under the
                        // keys.
                        ScrollView(.horizontal,
                                   showsIndicators: false) {
                            lanesContent(width: containerW)
                                .frame(width: metrics.contentWidth,
                                       height: Self.contentH,
                                       alignment: .topLeading)
                        }
                        .frame(height: Self.contentH)
                        .scrollPosition($hScrollPosition)
                        // Capture the horizontal offset (head
                        // notch + roller) and viewport width
                        // (pinch focal calc).
                        .onScrollGeometryChange(for: CGRect.self) { geo in
                            CGRect(x: geo.contentOffset.x, y: 0,
                                   width: geo.containerSize.width,
                                   height: 0)
                        } action: { _, new in
                            scrollOffset.x = max(0, new.minX)
                            viewportW = new.width
                        }
                        // Pinch anywhere on the lanes to zoom.
                        .simultaneousGesture(zoomGesture)

                        // Frozen piano column, overlaid on the
                        // leading edge so the lanes appear to
                        // emerge from under the keys.  Opaque,
                        // so the lane content behind it (and any
                        // notes scrolled under it) stays hidden.
                        pianoColumn
                            .frame(width: Self.whiteKeyW,
                                   height: Self.contentH,
                                   alignment: .topLeading)
                    }
                    .frame(maxWidth: .infinity,
                           minHeight: Self.contentH,
                           alignment: .topLeading)
                }
                .defaultScrollAnchor(.top)
                // Capture the VERTICAL offset too, so a tapped
                // note/point can be converted from lane-content
                // coords to screen coords for the edit menu anchor.
                .onScrollGeometryChange(for: CGFloat.self) { geo in
                    geo.contentOffset.y
                } action: { _, y in
                    scrollOffset.y = max(0, y)
                }

                // Head pinned to the very top — outside the
                // vertical scroll, so it never moves up/down.
                // Its notch still reacts to `scrollOffset.x`.
                // NO background behind the rest: the sheet's
                // own backdrop shows through the lane gaps as
                // the Figma's "empty areas".
                head(containerW: containerW)
                    .frame(width: containerW,
                           height: Self.headH)

                // Edit-menu host — Apple's UIEditMenuInteraction
                // (same EditMenuPresenter the main timeline uses).
                // Passthrough hit-testing, so it never blocks the
                // taps below; the menu is presented programmatically
                // at `sourcePoint` (already in this view's screen
                // space).
                EditMenuPresenter(
                    isPresented: Binding(
                        get: { menuPresentation != nil },
                        set: { if !$0 { menuPresentation = nil } }
                    ),
                    sourcePoint: menuPresentation?.sourcePoint ?? .zero,
                    actions: menuActions,
                    onAction: handleMenuAction
                )
                .frame(width: containerW,
                       height: proxy.size.height)
            }
            .clipShape(
                RoundedRectangle(cornerRadius: Self.containerR)
            )
        }
    }

    // MARK: Lanes content

    /// The SpaceBlue/IndigoBlue lane stripes + the note
    /// rectangles, laid out as a `laneW × contentH` block.
    /// This is now just CONTENT — the scrolling is owned by
    /// the two ScrollViews in `body` (vertical for pitch,
    /// horizontal for time).  Each lane is a centered stripe
    /// over a transparent slot, so the gaps between stripes
    /// stay empty — the striped Figma look.
    /// The lane stripes + grid + note rectangles, sized to the
    /// current zoom (`contentWidth × contentH`).  Scrolling is
    /// owned by the two ScrollViews in `body`.
    private func lanesContent(width containerW: CGFloat) -> some View {
        let contentW = metrics.contentWidth
        return ZStack(alignment: .topLeading) {

            // Lanes as a real VStack of KEY-sized slots
            // (whiteSlotH = 26, last = whiteKeyH = 24) so the
            // block has real bounds and lines up row-for-row
            // with the piano column, which uses the identical
            // slot sizing.
            VStack(alignment: .leading, spacing: 0) {

                // Top inset spacer — sets where the first lane
                // starts relative to the head (see `topInset`).
                Color.clear
                    .frame(width: contentW,
                           height: Self.topInset)

                ForEach(0..<Self.numWhiteKeys,
                        id: \.self) { i in
                    let isLast =
                        (i == Self.numWhiteKeys - 1)
                    let slotH: CGFloat = isLast
                        ? Self.whiteKeyH
                        : Self.whiteSlotH

                    ZStack(alignment: .topLeading) {
                        // Transparent bounds keeper — gives the
                        // slot real height without painting a
                        // background.
                        Color.clear
                            .frame(width: contentW,
                                   height: slotH)

                        // SpaceBlue white lane — 14pt, centered
                        // on the 24pt key (5pt empty above &
                        // below).
                        Rectangle()
                            .fill(Color("SpaceBlue"))
                            .frame(width: contentW,
                                   height: Self.whiteLaneH)
                            .offset(y: (Self.whiteKeyH
                                        - Self.whiteLaneH) / 2)

                        // IndigoBlue black lane straddling the
                        // boundary above — only where a black
                        // key exists (B→A♯→A yes; C→B and F→E
                        // no), leaving those gaps empty.
                        if i > 0
                          && Self.hasBlackAfter(i - 1) {
                            Rectangle()
                                .fill(Color("IndigoBlue"))
                                .frame(width: contentW,
                                       height: Self.blackLaneH)
                                .offset(y: -(Self.whiteSpacing / 2
                                             + Self.blackLaneH / 2))
                        }
                    }
                    .frame(width: contentW,
                           height: slotH,
                           alignment: .topLeading)
                }
            }

            // Bar/beat grid lines — same adaptive model as the
            // main timeline, culled to the visible window.
            // Drawn over the stripes, under the notes.
            PRGridCanvas(pixelsPerBar: pixelsPerBar,
                         scrollOffsetX: scrollOffset.x,
                         visibleWidth: containerW,
                         gridColor: gridColor)
                .equatable()

            // Tap-to-edit catcher.  Sits BELOW the notes so a tap
            // ON a note raises the note menu (the note wins) and a
            // tap on EMPTY timeline raises the empty menu here.  A
            // tap is distinct from a drag, so this doesn't interfere
            // with scrolling.
            Color.clear
                .contentShape(Rectangle())
                .frame(width: contentW, height: Self.contentH)
                .onTapGesture(coordinateSpace: .local) { loc in
                    presentEmptyMenu(atContentPoint: loc)
                }

            // Notes — absolutely-positioned via `.offset` on top of
            // the lane stripes + grid.  Tapping one raises its
            // Copy / Paste / Delete menu.
            ForEach(recorder.notes) { note in
                NoteRectangleView(note: note,
                                   recorder: recorder,
                                   metrics: metrics,
                                   onTap: { presentNoteMenu(for: $0) })
            }
        }
    }

    // MARK: Edit-menu plumbing

    /// Actions for whatever the menu currently targets.  A note
    /// gets Copy / Delete (plus Paste when the clipboard holds a
    /// note); empty space gets Add (plus Paste when the clipboard
    /// holds a note).
    private var menuActions: [EditMenuAction] {
        guard let target = menuPresentation?.target else { return [] }
        let canPaste = noteClipboard != nil
        switch target {
        case .note:
            var actions = [EditMenuAction(id: "copy", title: "Copy")]
            if canPaste {
                actions.append(EditMenuAction(id: "paste", title: "Paste"))
            }
            actions.append(EditMenuAction(id: "delete", title: "Delete",
                                          isDestructive: true))
            return actions
        case .emptySpace:
            var actions = [EditMenuAction(id: "add", title: "Add")]
            if canPaste {
                actions.append(EditMenuAction(id: "paste", title: "Paste"))
            }
            return actions
        }
    }

    /// Raise the empty-space menu at a tap.  Stores the snapped
    /// pitch/beat (so Add/Paste know where to land) and the
    /// screen-space anchor.  `loc` is in lane-content coords
    /// (includes the `topInset` spacer + the leading `leftMargin`
    /// hidden behind the keys).
    private func presentEmptyMenu(atContentPoint loc: CGPoint) {
        // Ignore the region hidden behind the piano keys.
        guard loc.x >= Self.leftMargin else { return }

        let m = metrics
        let step = m.scale.gridStepBeats
        let snappedBeat = (m.beat(forX: loc.x) / step)
            .rounded(.down) * step
        let midi = Self.midi(forY: loc.y - Self.topInset)

        menuPresentation = PRMenuPresentation(
            target: .emptySpace(beat: snappedBeat, midi: midi),
            sourcePoint: screenPoint(contentX: loc.x, contentY: loc.y))
    }

    /// Raise the note menu, anchored at the note's on-screen spot.
    private func presentNoteMenu(for note: RecordedNote) {
        let beat = note.startSeconds * recorder.bpm / 60
        let cx = metrics.x(forBeat: beat)
        let cy = Self.topInset + Self.laneY(for: note.midi)
        menuPresentation = PRMenuPresentation(
            target: .note(note),
            sourcePoint: screenPoint(contentX: cx, contentY: cy))
    }

    /// Convert a lane-content point to this view's screen space,
    /// undoing both scroll offsets so the menu anchors under the
    /// finger.
    private func screenPoint(contentX: CGFloat,
                             contentY: CGFloat) -> CGPoint {
        CGPoint(x: contentX - scrollOffset.x,
                y: contentY - scrollOffset.y)
    }

    /// Single entry point for every menu action.  Always dismisses
    /// the menu at the end.
    private func handleMenuAction(_ actionId: String) {
        defer { menuPresentation = nil }
        guard let target = menuPresentation?.target else { return }

        switch (actionId, target) {
        case ("add", .emptySpace(let beat, let midi)):
            insertNote(beat: beat, midi: midi,
                       durationBeats: 1.0, velocity: 100)

        case ("paste", .emptySpace(let beat, let midi)):
            pasteClipboard(beat: beat, midi: midi)

        case ("copy", .note(let note)):
            noteClipboard = note

        case ("paste", .note(let note)):
            // Paste at the tapped note's pitch/time.
            let beat = note.startSeconds * recorder.bpm / 60
            pasteClipboard(beat: beat, midi: note.midi)

        case ("delete", .note(let note)):
            recorder.deleteNote(note.id)

        default:
            break
        }
    }

    /// Add a note of the given length at a pitch/beat.
    private func insertNote(beat: Double, midi: UInt8,
                            durationBeats: Double, velocity: UInt8) {
        let startSec = beat * 60 / recorder.bpm
        let endSec   = (beat + durationBeats) * 60 / recorder.bpm
        recorder.addNote(midi: midi,
                         startSeconds: startSec,
                         endSeconds: endSec,
                         velocity: velocity)
    }

    /// Stamp a copy of the clipboard note (its length + velocity)
    /// at the given pitch/beat.
    private func pasteClipboard(beat: Double, midi: UInt8) {
        guard let clip = noteClipboard else { return }
        let durSec = (clip.endSeconds ?? clip.startSeconds)
                   - clip.startSeconds
        let durationBeats = max(0.01, durSec * recorder.bpm / 60)
        insertNote(beat: beat, midi: midi,
                   durationBeats: durationBeats,
                   velocity: clip.velocity)
    }

    // MARK: Piano column (frozen left column)

    /// 88 playable keys, built as a VStack of the SAME
    /// per-slot heights as the lanes content so the two line
    /// up row-for-row.  No manual offset/clip anymore — this
    /// is plain content; the ZStack + vertical ScrollView in
    /// `body` size it (`whiteKeyW × contentH`), overlay it on
    /// the lanes' leading edge, and scroll it.
    private var pianoColumn: some View {
        VStack(alignment: .leading, spacing: 0) {

            Color.clear
                .frame(width: Self.whiteKeyW,
                       height: Self.topInset)

            ForEach(0..<Self.numWhiteKeys, id: \.self) { i in
                let isLast = (i == Self.numWhiteKeys - 1)
                let slotH: CGFloat = isLast
                    ? Self.whiteKeyH
                    : Self.whiteSlotH

                ZStack(alignment: .topLeading) {
                    // White key fills the top 24pt of the
                    // slot; the remaining 2pt (the spacing
                    // gap) is empty.
                    PianoKey(
                        midi:     Self.whiteMidi(at: i),
                        isBlack:  false,
                        recorder: recorder)

                    // Black key BEFORE this slot — same
                    // straddling trick as the IndigoBlue lane:
                    // offset up 7pt so its 12pt height bridges
                    // the boundary between slot i-1 and slot i.
                    if i > 0 && Self.hasBlackAfter(i - 1) {
                        PianoKey(
                            midi: Self.whiteMidi(at: i - 1) - 1,
                            isBlack:  true,
                            recorder: recorder)
                        .offset(y: -(Self.whiteSpacing / 2
                                     + Self.blackKeyH / 2))
                    }
                }
                .frame(width: Self.whiteKeyW,
                       height: slotH,
                       alignment: .topLeading)
            }
        }
    }

    // MARK: Head (top overlay, static — only stripWidth
    //       changes with scrollOffset.x)

    /// Top strip — two SpaceBlue rectangles with drop
    /// shadows.  Outer has rounded top corners that line up
    /// with the card's rounded top corners; inner is a
    /// plain rect, right-aligned within the outer.  The
    /// chrome stays put; only the inner strip's width swaps
    /// (notch open ↔ notch closed) when the user pans.
    private func head(containerW: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {

            // Outer — full width × 25, SpaceBlue, rounded
            // top (matches card corners), drop shadow.
            spaceBlueShadowed(
                UnevenRoundedRectangle(
                    topLeadingRadius:     Self.containerR,
                    bottomLeadingRadius:  0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius:    Self.containerR
                )
            )
            .frame(width: containerW,
                   height: Self.headH)

            // Inner — stripWidth × 15, right-aligned within
            // the outer.  At scroll origin this is
            // `containerW − notchW` (notch visible);
            // `containerW` once scrolled (notch closes).
            spaceBlueShadowed(Rectangle())
                .frame(width: stripWidth(containerW: containerW),
                       height: Self.headInnerH)
                .frame(width: containerW,
                       alignment: .topTrailing)

            // Roller — bar numbers + tick hierarchy, drawn on
            // top of the inner strip and scrolled left/right in
            // lockstep with the lanes.  Ticks hang up from the
            // head's bottom edge so they meet the lane grid
            // lines.  Marks left of the keys are skipped, so the
            // roller only fills the lane area.
            PRRulerCanvas(pixelsPerBar: pixelsPerBar,
                          scrollOffsetX: scrollOffset.x,
                          containerW: containerW,
                          tickColor: tickColor)
        }
        .frame(width: containerW,
               height: Self.headH,
               alignment: .topLeading)
    }

    /// Apply the head's SpaceBlue fill + drop shadow to any
    /// Shape so the outer (rounded) and inner (rectangle)
    /// rects can share styling.  Lifted from
    /// MainTimelineView's `spaceBlueShadowed`.
    private func spaceBlueShadowed<S: Shape>(_ shape: S) -> some View {
        shape
            .fill(Color("SpaceBlue"))
            .shadow(color: .black.opacity(0.25),
                    radius: 4, x: 0, y: 4)
    }
}

// MARK: - Piano-roll timeline model
//
// Mirrors MainTimelineView's `TLMetrics`/`TLScale` so the roll's
// grid + roller line up with the main timeline.  Reuses the
// shared `TLLayout` constants (beatsPerBar, totalBars, tick
// sizes, zoom range) so the two never drift; only the zoom value
// (`pixelsPerBar`) is owned independently by the roll.

private struct PRScale {
    var labelStride: Int       // bars between numbers
    var tickStepBeats: Double  // finest tick spacing (beats)
    var gridStepBeats: Double  // grid-line spacing (beats)
}

private struct PRMetrics: Equatable {
    let pixelsPerBar: CGFloat

    var pixelsPerBeat: CGFloat {
        pixelsPerBar / CGFloat(TLLayout.beatsPerBar)
    }
    /// x in LANE-CONTENT coordinates.  Beat 0 sits at the keys'
    /// trailing edge (`leftMargin`), so the grid and notes line
    /// up with where the lanes emerge from under the piano.
    func x(forBeat beat: Double) -> CGFloat {
        PianoRollView.leftMargin + CGFloat(beat) * pixelsPerBeat
    }
    func beat(forX xPos: CGFloat) -> Double {
        Double(max(0, xPos - PianoRollView.leftMargin) / pixelsPerBeat)
    }
    var totalBeats: Double {
        Double(TLLayout.totalBars * TLLayout.beatsPerBar)
    }
    var contentWidth: CGFloat {
        x(forBeat: totalBeats) + pixelsPerBar
    }
    var scale: PRScale {
        let bpb = Double(TLLayout.beatsPerBar)
        switch pixelsPerBar {
        case ..<80:
            return PRScale(labelStride: 4, tickStepBeats: 1,
                           gridStepBeats: bpb)        // 1 bar
        case 80..<160:
            return PRScale(labelStride: 2, tickStepBeats: 1,
                           gridStepBeats: bpb / 2)    // 1/2 bar
        case 160..<320:
            return PRScale(labelStride: 1, tickStepBeats: 1,
                           gridStepBeats: 1)          // 1 beat
        case 320..<640:
            return PRScale(labelStride: 1, tickStepBeats: 0.5,
                           gridStepBeats: 0.5)        // 1/8 note
        default:
            return PRScale(labelStride: 1, tickStepBeats: 0.25,
                           gridStepBeats: 0.25)       // 1/16 note
        }
    }
}

// MARK: - Grid canvas (lanes; vertical bar/beat lines)

/// Vertical grid lines spanning the lane area.  Lives INSIDE the
/// horizontal scroll, so it draws in content coordinates
/// (`x(forBeat:)`) and the scroll translates it; it only redraws
/// on zoom or horizontal scroll (Equatable), and culls to the
/// visible beat window so deep zoom doesn't emit 100k+ lines.
private struct PRGridCanvas: View, Equatable {
    let pixelsPerBar: CGFloat
    let scrollOffsetX: CGFloat
    let visibleWidth: CGFloat
    let gridColor: Color

    static func == (l: PRGridCanvas, r: PRGridCanvas) -> Bool {
        l.pixelsPerBar == r.pixelsPerBar &&
        l.scrollOffsetX == r.scrollOffsetX &&
        l.visibleWidth == r.visibleWidth
    }

    var body: some View {
        let m = PRMetrics(pixelsPerBar: pixelsPerBar)
        let s = m.scale
        let margin = pixelsPerBar
        let firstBeat = max(0, m.beat(forX: scrollOffsetX - margin))
        let lastBeat  = min(m.totalBeats,
                            m.beat(forX: scrollOffsetX
                                   + visibleWidth + margin))
        let contentW  = m.contentWidth
        let top       = PianoRollView.topInset
        let bottom    = PianoRollView.contentH

        return Canvas { context, _ in
            let gw = TLLayout.gridWeight
            var g = (firstBeat / s.gridStepBeats).rounded(.down)
            while g * s.gridStepBeats <= lastBeat {
                let bp = g * s.gridStepBeats
                let gx = m.x(forBeat: bp)
                context.fill(
                    Path(CGRect(x: gx - gw / 2, y: top,
                                width: gw, height: bottom - top)),
                    with: .color(gridColor))
                g += 1
            }
        }
        .frame(width: contentW, height: PianoRollView.contentH)
    }
}

// MARK: - Roller canvas (head; bar numbers + ticks)

/// Bar numbers and the tick hierarchy, drawn in the head strip.
/// Lives OUTSIDE the scroll (the head is a fixed overlay), so it
/// draws in SCREEN coordinates (`x(forBeat:) - scrollOffsetX`).
/// Ticks hang UP from the head's bottom edge so they meet the
/// lane grid lines below.  Marks left of the keys are skipped.
private struct PRRulerCanvas: View {
    let pixelsPerBar: CGFloat
    let scrollOffsetX: CGFloat
    let containerW: CGFloat
    let tickColor: Color

    var body: some View {
        let m = PRMetrics(pixelsPerBar: pixelsPerBar)
        let s = m.scale
        let bpb = Double(TLLayout.beatsPerBar)
        let margin = pixelsPerBar
        let firstBeat = max(0, m.beat(forX: scrollOffsetX - margin))
        let lastBeat  = min(m.totalBeats,
                            m.beat(forX: scrollOffsetX
                                   + containerW + margin))

        return Canvas { context, _ in
            let headH = PianoRollView.headH
            let tw = TLLayout.tickWeight

            var t = (firstBeat / s.tickStepBeats).rounded(.down)
            while t * s.tickStepBeats <= lastBeat {
                let bp = t * s.tickStepBeats
                t += 1
                let screenX = m.x(forBeat: bp) - scrollOffsetX
                // Never let marks creep left of the keys.
                if screenX < PianoRollView.leftMargin { continue }

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
                    Path(CGRect(x: screenX - tw / 2, y: headH - len,
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
                            x: screenX + tw / 2 + TLLayout.numberGap,
                            y: TLLayout.rulerTopInset),
                        anchor: .topLeading)
                }
            }
        }
        .frame(width: containerW, height: PianoRollView.headH)
    }
}

// MARK: - PianoKey

/// One playable key.  Tap-and-hold fires `noteOn` on the
/// bound recorder's audio output; lifting (or the gesture
/// cancelling) fires `noteOff`.  The `isHeld` flag guards
/// against the continuous-onChanged firing of `DragGesture
/// (minimumDistance: 0)` so we only emit a single noteOn per
/// touch.
private struct PianoKey: View {
    let midi: UInt8
    let isBlack: Bool
    let recorder: TrackRecorder

    @State private var isHeld = false

    private var keyW: CGFloat {
        isBlack ? PianoRollView.blackKeyW
                : PianoRollView.whiteKeyW
    }
    private var keyH: CGFloat {
        isBlack ? PianoRollView.blackKeyH
                : PianoRollView.whiteKeyH
    }

    var body: some View {
        UnevenRoundedRectangle(
            topLeadingRadius:     0,
            bottomLeadingRadius:  0,
            bottomTrailingRadius: PianoRollView.keyCornerR,
            topTrailingRadius:    PianoRollView.keyCornerR
        )
        .fill(isBlack ? Color.black : Color.white)
        .frame(width: keyW, height: keyH)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard !isHeld else { return }
                    isHeld = true
                    recorder.audioOutput?.noteOn(
                        midi: midi, velocity: 88)
                }
                .onEnded { _ in
                    guard isHeld else { return }
                    isHeld = false
                    recorder.audioOutput?.noteOff(midi: midi)
                }
        )
    }
}

// MARK: - NoteRectangleView

/// One note rectangle in the piano roll.  Draggable to a
/// new lane (Y) and time (X); right edge is a separate hit
/// target that resizes by adjusting `endSeconds` only.
/// Body-drag shifts both `startSeconds` and `endSeconds` by
/// the same amount so the note's duration is preserved.
///
/// Both gestures use `UIKitDragGesture` (frame-tight
/// translation deltas) plus `transaction.disablesAnimations
/// = true` so the drag doesn't go through SwiftUI's
/// animation pipeline.
private struct NoteRectangleView: View {

    let note: RecordedNote
    let recorder: TrackRecorder
    /// Beat ↔ x model (carries the live zoom).  Note times stay
    /// stored in seconds; we convert via the recorder's bpm so a
    /// note's bar position matches the grid and the main timeline.
    let metrics: PRMetrics
    /// Fired on a tap (no movement) — the parent raises this note's
    /// Copy / Paste / Delete edit menu.  A drag still moves the
    /// note; the right edge still resizes.
    let onTap: (RecordedNote) -> Void

    @State private var dragOffset:  CGSize  = .zero
    @State private var resizeDelta: CGFloat = 0

    private var bpm: Double { recorder.bpm }
    private var startBeat: Double {
        note.startSeconds * bpm / 60
    }
    private var endBeat: Double {
        (note.endSeconds ?? note.startSeconds) * bpm / 60
    }

    private var laneIsBlack: Bool {
        PianoRollView.isBlack(note.midi)
    }
    /// Lane VISUAL height — the SpaceBlue/IndigoBlue stripe
    /// behind the note.  Used for the `midi(forY:)` lookup at
    /// drag end and for the note rect's outer frame.
    private var laneH: CGFloat {
        laneIsBlack
            ? PianoRollView.blackLaneH
            : PianoRollView.whiteLaneH
    }
    /// Note RECTANGLE height — equals the lane height on both
    /// white (14) and black (12), so the purple note exactly
    /// covers its lane stripe.
    private var noteH: CGFloat {
        laneIsBlack
            ? PianoRollView.blackNoteH
            : PianoRollView.whiteNoteH
    }
    /// Y position in scroll-content coords — `topInset`
    /// spacer plus the lane's Y inside the piano content,
    /// plus a centering offset (zero now that lane == note
    /// height).
    private var baseY: CGFloat {
        PianoRollView.topInset
            + PianoRollView.laneY(for: note.midi)
            + (laneH - noteH) / 2
    }
    /// X position — the note's start beat mapped through the
    /// zoom model (beat 0 sits at the keys' edge).
    private var baseX: CGFloat {
        metrics.x(forBeat: startBeat)
    }
    private var baseWidth: CGFloat {
        let w = CGFloat(max(0, endBeat - startBeat))
              * metrics.pixelsPerBeat
        return max(PianoRollView.noteDefaultW, w)
    }
    private var currentWidth: CGFloat {
        max(8, baseWidth + resizeDelta)
    }

    var body: some View {
        ZStack(alignment: .trailing) {

            RoundedRectangle(cornerRadius: 2,
                             style: .continuous)
                .fill(Color("MainPurple").opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 2,
                                     style: .continuous)
                        .strokeBorder(Color("Lavender"),
                                      lineWidth: 1)
                )
                .frame(width: currentWidth, height: noteH)
                .overlay {
                    UIKitDragGesture(
                        onTap: { _ in
                            // Tap (no movement) raises this note's
                            // edit menu; a drag still moves it.
                            onTap(note)
                        },
                        onChanged: { t in
                            dragOffset = CGSize(
                                width: t.x, height: t.y)
                        },
                        onEnded: { t in
                            // `midi(forY:)` expects piano-
                            // content coords (no spacer), so
                            // subtract `topInset` from the
                            // computed Y before lookup.
                            // `t.y` is measured from the note
                            // rect's TOP, so its CENTER after
                            // the drag is `baseY + t.y +
                            // noteH / 2`.
                            let finalY = baseY + t.y
                                       + noteH / 2
                                       - PianoRollView.topInset
                            let newMidi =
                                PianoRollView.midi(forY: finalY)

                            let dxBeats = Double(
                                t.x / metrics.pixelsPerBeat)
                            let dxSec = TimeInterval(
                                dxBeats * 60 / bpm)
                            let oldStart = note.startSeconds
                            let oldEnd =
                                note.endSeconds ?? oldStart
                            let duration = oldEnd - oldStart
                            let newStart =
                                max(0, oldStart + dxSec)

                            recorder.setNoteStart(
                                note.id, newStart)
                            if note.endSeconds != nil {
                                recorder.setNoteEnd(
                                    note.id,
                                    newStart + duration)
                            }
                            recorder.setNoteMidi(
                                note.id, newMidi)
                            dragOffset = .zero
                        }
                    )
                }

            Color.clear
                .contentShape(Rectangle())
                .frame(width: 8, height: noteH)
                .overlay(alignment: .trailing) {
                    Rectangle()
                        .fill(Color("Lavender"))
                        .frame(width: 1,
                               height: max(2, noteH - 4))
                        .padding(.trailing, 2)
                }
                .overlay {
                    UIKitDragGesture(
                        onChanged: { t in
                            resizeDelta = t.x
                        },
                        onEnded: { t in
                            let newWidth = max(
                                8, baseWidth + t.x)
                            let durationBeats = Double(
                                newWidth / metrics.pixelsPerBeat)
                            let durationSec = TimeInterval(
                                durationBeats * 60 / bpm)
                            let newEnd =
                                note.startSeconds + durationSec
                            recorder.setNoteEnd(
                                note.id, newEnd)
                            resizeDelta = 0
                        }
                    )
                }
        }
        .frame(width: currentWidth,
               height: laneH,
               alignment: .leading)
        .offset(x: baseX + dragOffset.width,
                y: baseY + dragOffset.height)
        .transaction { transaction in
            transaction.animation = nil
            transaction.disablesAnimations = true
        }
    }
}

// MARK: - Preview

/// Showroom preview — places the card on a dark canvas so
/// the SpaceBlue/IndigoBlue stripes, the head's drop shadow,
/// and the notes all read at sheet-detent proportions
/// (393 × 322 ≈ what CreationView gives this).
#Preview {
    Color.black
        .ignoresSafeArea()
        .overlay {
            PianoRollView(recorder: previewRecorderWithNotes())
                .frame(width: 393, height: 322)
        }
}

private func previewRecorderWithNotes() -> TrackRecorder {
    let r = TrackRecorder()
    // Preview notes placed in the C7..C8 range so they're
    // visible in the static Xcode canvas (which now opens
    // pinned to C8 at the top).
    let snap = TrackSnapshot(
        notes: [
            RecordedNote(midi: 108, startSeconds: 0.2,
                         endSeconds: 0.6, velocity: 88), // C8
            RecordedNote(midi: 105, startSeconds: 0.7,
                         endSeconds: 1.1, velocity: 88), // A7
            RecordedNote(midi: 103, startSeconds: 1.2,
                         endSeconds: 1.6, velocity: 88), // G7
            RecordedNote(midi: 101, startSeconds: 1.7,
                         endSeconds: 2.1, velocity: 88), // F7
            RecordedNote(midi:  98, startSeconds: 2.2,
                         endSeconds: 2.6, velocity: 88), // D7
            RecordedNote(midi:  96, startSeconds: 2.7,
                         endSeconds: 3.1, velocity: 88), // C7
        ],
        duration: 4.0,
        name: "Preview"
    )
    r.loadSnapshot(snap, atStartSec: 0)
    return r
}


