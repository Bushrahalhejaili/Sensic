//
//  PianoKeyboard.swift
//  Sensic
//
//  Created by Bushra Hatim Alhejaili on 31/05/2026.
//
//  The piano keyboard surface — keys, scroller strip, and the
//  combined keyboard-plus-scroller view. Shared between Record
//  mode (in CreationView) and Practice mode.
//


//
//  PianoKeyboard.swift
//  Sensic
//
//  Created by Bushra Hatim Alhejaili on 31/05/2026.
//
//  The piano keyboard surface — keys, scroller strip, and the
//  combined keyboard-plus-scroller view. Shared between Record
//  mode (in CreationView) and Practice mode.
//


//
//  PianoKeyboard.swift
//  Sensic
//
//  Created by Bushra Hatim Alhejaili on 31/05/2026.
//
//  The piano keyboard surface — keys, scroller strip, and the
//  combined keyboard-plus-scroller view. Shared between Record
//  mode (in CreationView) and Practice mode.
//


import SwiftUI
import UIKit

// ─────────────────────────────────────────────
// MARK: - Piano Constants
// ─────────────────────────────────────────────

let wKW: CGFloat = 56       // White key width
let wKH: CGFloat = 220      // White key height
let bKW: CGFloat = 36       // Black key width
let bKH: CGFloat = 139      // Black key height
let wKSpacing: CGFloat = 2  // Gap between adjacent white keys
let keyCornerRadius: CGFloat = 10  // Bottom-corner radius (white + black)

/// Horizontal stride from one white key to the next.
let wKStride: CGFloat = wKW + wKSpacing  // 58

// ─────────────────────────────────────────────
// MARK: - Piano Key Model
// ─────────────────────────────────────────────

struct PianoKeyModel: Identifiable {
    let id      = UUID()
    let midi:     UInt8
    let isBlack:  Bool
    let noteName: String
    let octave:   Int
}

private let _blackPat: [Bool] = [
    false,true,false,true,false,false,true,false,true,false,true,false
]

func buildPianoKeys() -> [PianoKeyModel] {
    let names = ["C","C#","D","D#","E","F","F#","G","G#","A","A#","B"]
    var result: [PianoKeyModel] = []
    // A0 (MIDI 21) through C8 (MIDI 108) — standard 88-key piano:
    // 52 white keys + 36 black keys.
    for midi in 21...108 {
        result.append(PianoKeyModel(
            midi:     UInt8(midi),
            isBlack:  _blackPat[midi % 12],
            noteName: names[midi % 12],
            octave:   midi / 12 - 1
        ))
    }
    return result
}

let allPianoKeys   = buildPianoKeys()
let whitePianoKeys = allPianoKeys.filter { !$0.isBlack }
let blackPianoKeys = allPianoKeys.filter {  $0.isBlack }

/// Black key x-position: centered on the boundary between the two
/// surrounding white keys (standard piano layout).
func blackKeyOffset(_ midi: UInt8) -> CGFloat? {
    var whiteCount: CGFloat = 0
    for key in allPianoKeys {
        if key.midi == midi { return whiteCount * wKStride - bKW / 2 }
        if !key.isBlack { whiteCount += 1 }
    }
    return nil
}

/// Builds a rounded path with only the bottom-left and bottom-right
/// corners rounded — used for both white and black keys.
private func bottomRoundedPath(in rect: CGRect, radius: CGFloat) -> UIBezierPath {
    UIBezierPath(
        roundedRect: rect,
        byRoundingCorners: [.bottomLeft, .bottomRight],
        cornerRadii: CGSize(width: radius, height: radius)
    )
}

// ─────────────────────────────────────────────
// MARK: - PianoUIView
// ─────────────────────────────────────────────

class PianoUIView: UIView {
    var onNoteOn:  ((UInt8, UInt8) -> Void)?
    var onNoteOff: ((UInt8) -> Void)?
    var activeNotes = Set<UInt8>() { didSet { setNeedsDisplay() } }
    private var touchToMidi: [UITouch: UInt8] = [:]

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        backgroundColor = .clear
    }
    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ rect: CGRect) {
        // White keys (drawn first, behind the black keys)
        for (i, key) in whitePianoKeys.enumerated() {
            let x = CGFloat(i) * wKStride
            let r = CGRect(x: x, y: 0, width: wKW, height: wKH)
            let path = bottomRoundedPath(in: r, radius: keyCornerRadius)
            (activeNotes.contains(key.midi)
                ? UIColor(white: 0.78, alpha: 1)
                : UIColor.white).setFill()
            path.fill()
            UIColor.black.withAlphaComponent(0.1).setStroke()
            path.lineWidth = 0.5; path.stroke()
            if key.noteName == "C" {
                let attr: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 11, weight: .semibold),
                    .foregroundColor: activeNotes.contains(key.midi)
                        ? UIColor.darkGray : UIColor.gray
                ]
                let str = NSAttributedString(string: "C\(key.octave)", attributes: attr)
                let sz  = str.size()
                str.draw(at: CGPoint(x: x + (wKW - sz.width) / 2, y: wKH - sz.height - 10))
            }
        }
        // Black keys (drawn on top)
        for key in blackPianoKeys {
            guard let x = blackKeyOffset(key.midi) else { continue }
            let r = CGRect(x: x, y: 0, width: bKW, height: bKH)
            let path = bottomRoundedPath(in: r, radius: keyCornerRadius)
            (activeNotes.contains(key.midi)
                ? UIColor(white: 0.45, alpha: 1)
                : UIColor(white: 0.1, alpha: 1)).setFill()
            path.fill()
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches {
            if let m = midiAt(t.location(in: self)) {
                touchToMidi[t] = m
                onNoteOn?(m, touchVelocity(t))
            }
        }
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches {
            let curr = midiAt(t.location(in: self)); let prev = touchToMidi[t]
            if curr != prev {
                if let p = prev { onNoteOff?(p) }
                if let c = curr {
                    touchToMidi[t] = c
                    onNoteOn?(c, touchVelocity(t))
                } else {
                    touchToMidi[t] = nil
                }
            }
        }
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches { if let m = touchToMidi[t] { onNoteOff?(m) }; touchToMidi[t] = nil }
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEnded(touches, with: event)
    }
    private func midiAt(_ pt: CGPoint) -> UInt8? {
        for key in blackPianoKeys {
            guard let x = blackKeyOffset(key.midi) else { continue }
            if CGRect(x: x, y: 0, width: bKW, height: bKH).contains(pt) { return key.midi }
        }
        for (i, key) in whitePianoKeys.enumerated() {
            if CGRect(x: CGFloat(i) * wKStride, y: 0, width: wKW, height: wKH).contains(pt) { return key.midi }
        }
        return nil
    }

    /// Map the Y position of the touch within the key to a MIDI
    /// velocity. Touching near the keytip (small Y) reads as a
    /// soft press; touching near the keybed (large Y) reads as a
    /// hard press — mirrors how a real piano's velocity response
    /// feels as the strike point moves from finger-tap to thumb-
    /// thump.
    ///
    /// Normalized against `wKH` (white-key height, 220pt). Black
    /// keys are shorter (`bKH` = 139pt) but their touches share
    /// the same Y axis — normalizing against the larger range
    /// means the bottom of a black key (~Y=139) maps to a mid-
    /// high velocity, which is what the player intuits since you
    /// can't physically press a black key past its visible end.
    ///
    /// Output range: 48 (soft) → 112 (hard). Stays inside the
    /// MIDI 0-127 spec with headroom on both ends so future
    /// accent / ghost-note layers have room to push past these.
    ///
    /// Replaces an earlier Force Touch implementation that, since
    /// Apple removed Force Touch hardware after the iPhone XS,
    /// always returned the constant 88 on modern devices.
    private func touchVelocity(_ touch: UITouch) -> UInt8 {
        let y = touch.location(in: self).y
        let normalized = max(0, min(1, y / wKH))
        return UInt8(48 + normalized * 64)
    }
}

// ─────────────────────────────────────────────
// MARK: - PianoScrollUIView
// ─────────────────────────────────────────────

class PianoScrollUIView: UIScrollView, UIGestureRecognizerDelegate {
    override func gestureRecognizerShouldBegin(_ g: UIGestureRecognizer) -> Bool {
        if let pan = g as? UIPanGestureRecognizer {
            let v = pan.velocity(in: self); return abs(v.x) > abs(v.y)
        }
        return true
    }
    func gestureRecognizer(_ g: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith o: UIGestureRecognizer) -> Bool { true }
}

// ─────────────────────────────────────────────
// MARK: - PianoSection
// ─────────────────────────────────────────────

struct PianoSection: UIViewRepresentable {
    @ObservedObject var vm: AudioEngine
    @ObservedObject var scrollState: PianoScrollState

    func makeUIView(context: Context) -> PianoScrollUIView {
        let totalW = PianoScrollState.totalContentWidth
        let piano = PianoUIView(frame: CGRect(x: 0, y: 0, width: totalW, height: wKH))
        piano.onNoteOn = { midi, velocity in
            DispatchQueue.main.async {
                vm.noteOn(midi: midi, velocity: velocity)
            }
        }
        piano.onNoteOff = { midi in DispatchQueue.main.async { vm.noteOff(midi: midi) } }
        context.coordinator.pianoView = piano

        let scroll = PianoScrollUIView()
        scroll.showsHorizontalScrollIndicator = false
        scroll.showsVerticalScrollIndicator = false
        scroll.backgroundColor = .clear
        // Disable user-initiated scrolling on the main piano
        // entirely.  The PianoScroller strip above is the only
        // intended way for the user to move the keyboard
        // horizontally — letting both surfaces drive scrolling
        // caused chords on the piano to slide out from under the
        // user when a finger drifted sideways.  Programmatic
        // scrolling via `scrollState.setOffset` → `setContentOffset`
        // is unaffected by this flag, so the PianoScroller still
        // controls the position normally.
        scroll.isScrollEnabled = false
        scroll.delegate = context.coordinator
        scroll.addSubview(piano)
        scroll.contentSize = CGSize(width: totalW, height: wKH)
        context.coordinator.scrollState = scrollState
        scrollState.scrollView = scroll
        DispatchQueue.main.async {
            scrollState.viewportWidth = scroll.bounds.width
            scrollState.setOffset(scrollState.offset)
        }
        return scroll
    }

    func updateUIView(_ uiView: PianoScrollUIView, context: Context) {
        context.coordinator.pianoView?.activeNotes = vm.activeNotes
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        var pianoView: PianoUIView?
        weak var scrollState: PianoScrollState?

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            Task { @MainActor in
                scrollState?.offset = scrollView.contentOffset.x
                scrollState?.viewportWidth = scrollView.bounds.width
            }
        }
    }
}

// ─────────────────────────────────────────────
// MARK: - PianoScroller
//
//   Minimap-style strip that sits above the piano
//   keyboard. Contains 52 vertical capsule lines —
//   one per white key on an 88-key piano (A0..C8),
//   grouped in eight blocks. The 3rd line in every
//   block is a C note and renders in white.
//
//   A draggable lavender-stroked picker sits on
//   top and represents the visible viewport of the
//   keyboard; dragging it scrolls the piano, and
//   scrolling the piano moves it.
// ─────────────────────────────────────────────

struct PianoScroller: View {
    @ObservedObject var scrollState: PianoScrollState

    /// When `true`, the scroller renders at its landscape (Record-mode
    /// only) dimensions — 864×25 with a wider 217pt picker and chunkier
    /// 5×15 lines.  Defaults to `false` (portrait 392×45) so every
    /// existing call site keeps working unchanged.
    var landscape: Bool = false

    // ─────────────────────────────────────────────
    // Container — portrait
    // ─────────────────────────────────────────────
    static let width: CGFloat        = 392
    static let height: CGFloat       = 45
    static let cornerRadius: CGFloat = 20
    static let strokeWidth: CGFloat  = 1

    // Container — landscape (per the Record-mode design spec)
    static let landscapeWidth: CGFloat        = 864
    static let landscapeHeight: CGFloat       = 25
    static let landscapeCornerRadius: CGFloat = 12

    // ─────────────────────────────────────────────
    // Lines — portrait
    // ─────────────────────────────────────────────
    static let lineHeight: CGFloat       = 25
    static let lineWidth: CGFloat        = 2
    /// Center-to-center distance between adjacent lines inside a group.
    static let intraGroupStride: CGFloat = 6
    /// Center-to-center distance from the last line of a group to the
    /// first line of the next group.
    static let interGroupStride: CGFloat = 10
    /// X-coordinate of the very first line's center, measured from the
    /// rectangle's leading edge. Mirrored on the right side.
    static let firstLineInset: CGFloat   = 29

    // Lines — landscape
    //
    // The line dimensions are an explicit spec from the design:
    // each line is 5pt wide and 15pt tall (taller capsule pill on a
    // shorter strip).  The horizontal spacings (`first inset`,
    // intra-group, inter-group) are scaled from the portrait values
    // by the container-width ratio so the same 8-group, 52-line
    // layout fills the wider rectangle without crowding or gaps.
    static let landscapeLineHeight: CGFloat = 15
    static let landscapeLineWidth: CGFloat  = 5
    private static let landscapeScale: CGFloat
        = landscapeWidth / width                         //   ≈ 2.204
    static let landscapeIntraGroupStride: CGFloat
        = intraGroupStride * landscapeScale              //   ≈ 13.22
    static let landscapeInterGroupStride: CGFloat
        = interGroupStride * landscapeScale              //   ≈ 22.04
    static let landscapeFirstLineInset: CGFloat
        = firstLineInset * landscapeScale                //   ≈ 63.92

    // ─────────────────────────────────────────────
    // Picker (viewport indicator) — portrait
    // ─────────────────────────────────────────────
    static let pickerWidth: CGFloat        = 46
    static let pickerHeight: CGFloat       = 45
    static let pickerCornerRadius: CGFloat = 14
    static let pickerStrokeWidth: CGFloat  = 2

    // Picker — landscape
    static let landscapePickerWidth: CGFloat        = 217
    static let landscapePickerHeight: CGFloat       = 25
    static let landscapePickerCornerRadius: CGFloat = 10

    // ─────────────────────────────────────────────
    // Effective dimensions — selected by `landscape`
    // ─────────────────────────────────────────────
    private var effectiveWidth: CGFloat        { landscape ? Self.landscapeWidth : Self.width }
    private var effectiveHeight: CGFloat       { landscape ? Self.landscapeHeight : Self.height }
    private var effectiveCornerRadius: CGFloat { landscape ? Self.landscapeCornerRadius : Self.cornerRadius }
    private var effectiveLineHeight: CGFloat   { landscape ? Self.landscapeLineHeight : Self.lineHeight }
    private var effectiveLineWidth: CGFloat    { landscape ? Self.landscapeLineWidth : Self.lineWidth }
    private var effectiveIntraStride: CGFloat  { landscape ? Self.landscapeIntraGroupStride : Self.intraGroupStride }
    private var effectiveInterStride: CGFloat  { landscape ? Self.landscapeInterGroupStride : Self.interGroupStride }
    private var effectiveFirstInset: CGFloat   { landscape ? Self.landscapeFirstLineInset : Self.firstLineInset }
    private var effectivePickerWidth: CGFloat        { landscape ? Self.landscapePickerWidth : Self.pickerWidth }
    private var effectivePickerHeight: CGFloat       { landscape ? Self.landscapePickerHeight : Self.pickerHeight }
    private var effectivePickerCornerRadius: CGFloat { landscape ? Self.landscapePickerCornerRadius : Self.pickerCornerRadius }

    /// 8 groups: seven of 7 lines, the last of 3.  Total = 7×7 + 3 = 52.
    private static let groupSizes: [Int] = [7, 7, 7, 7, 7, 7, 7, 3]

    /// The 3rd line of every group (zero-indexed = 2) is a C note.
    private static let cIndexInGroup = 2

    /// (x-center, isC) for each of the 52 lines.  Per-instance
    /// because the spacings now depend on `landscape`.
    private var lineLayout: [(x: CGFloat, isC: Bool)] {
        var out: [(CGFloat, Bool)] = []
        var x = effectiveFirstInset
        for (gi, count) in Self.groupSizes.enumerated() {
            for li in 0..<count {
                out.append((x, li == Self.cIndexInGroup))
                if li < count - 1 { x += effectiveIntraStride }
            }
            if gi < Self.groupSizes.count - 1 { x += effectiveInterStride }
        }
        return out
    }

    /// Travel range for the picker's center, in container coordinates.
    /// Per-instance for the same reason as `lineLayout`.
    private var pickerMinX: CGFloat { effectivePickerWidth / 2 }
    private var pickerMaxX: CGFloat { effectiveWidth - effectivePickerWidth / 2 }

    /// Captured normalized offset at the moment a drag begins, so
    /// `gesture.translation` can be added to a stable starting point.
    @State private var dragStartNorm: CGFloat?

    var body: some View {
        ZStack {
            // Background fill
            RoundedRectangle(
                cornerRadius: effectiveCornerRadius,
                style: .continuous
            )
            .fill(Color("Navy"))

            // 52 vertical lines (50 MainPurple + 8 white Cs)
            ForEach(0..<lineLayout.count, id: \.self) { i in
                let cfg = lineLayout[i]
                Capsule()
                    .fill(cfg.isC ? Color.white : Color("MainPurple"))
                    .frame(width: effectiveLineWidth, height: effectiveLineHeight)
                    .position(x: cfg.x, y: effectiveHeight / 2)
            }

            // Border on top so it remains crisp over the lines
            RoundedRectangle(
                cornerRadius: effectiveCornerRadius,
                style: .continuous
            )
            .strokeBorder(Color("MainPurple"), lineWidth: Self.strokeWidth)

            // Viewport picker, on top of everything
            picker
        }
        .frame(width: effectiveWidth, height: effectiveHeight)
        // Clip to the container so the picker can travel flush to the
        // edges without poking past the rounded corners.
        .clipShape(
            RoundedRectangle(
                cornerRadius: effectiveCornerRadius,
                style: .continuous
            )
        )
    }

    // MARK: Picker

    /// The viewport indicator. Its x-position is derived from the
    /// piano's normalized scroll offset; dragging it horizontally
    /// updates that offset which in turn scrolls the keyboard.
    private var picker: some View {
        let norm = max(0, min(1, scrollState.normalizedOffset))
        let centerX = pickerMinX + norm * (pickerMaxX - pickerMinX)

        return RoundedRectangle(
            cornerRadius: effectivePickerCornerRadius,
            style: .continuous
        )
        .fill(Color.gray.opacity(0.08))
        .overlay(
            RoundedRectangle(
                cornerRadius: effectivePickerCornerRadius,
                style: .continuous
            )
            .strokeBorder(
                Color("Lavender"),
                lineWidth: Self.pickerStrokeWidth
            )
        )
        .frame(width: effectivePickerWidth, height: effectivePickerHeight)
        .position(x: centerX, y: effectiveHeight / 2)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { gesture in
                    if dragStartNorm == nil {
                        dragStartNorm = scrollState.normalizedOffset
                    }
                    let travel = pickerMaxX - pickerMinX
                    let delta  = gesture.translation.width / travel
                    let newNorm = (dragStartNorm ?? 0) + delta
                    scrollState.setNormalizedOffset(
                        max(0, min(1, newNorm))
                    )
                }
                .onEnded { _ in
                    dragStartNorm = nil
                }
        )
    }
}

// ─────────────────────────────────────────────
// MARK: - PianoWithScroller
//
//   Vertical stack of the PianoScroller strip
//   above the scrollable piano keyboard.
// ─────────────────────────────────────────────

struct PianoWithScroller: View {
    @ObservedObject var vm: AudioEngine
    @ObservedObject var scrollState: PianoScrollState

    /// Vertical gap between the scroller strip and the keys.
    static let internalSpacing: CGFloat = 10

    var body: some View {
        VStack(spacing: Self.internalSpacing) {
            PianoScroller(scrollState: scrollState)
            PianoSection(vm: vm, scrollState: scrollState)
                .frame(height: wKH)
        }
    }
}

// ─────────────────────────────────────────────
// MARK: - CreationLayout
//
//   Piano block layout helper. Lives here because
//   all its inputs are piano-derived (scroller
//   height + internal spacing + key height).
// ─────────────────────────────────────────────

enum CreationLayout {
    /// Total block height = scroller + internal spacing + keys.
    static let pianoBlockHeight: CGFloat =
        PianoScroller.height
        + PianoWithScroller.internalSpacing
        + wKH
}
