// CreationComponents.swift
// Sensic
import SwiftUI
import UIKit

// ─────────────────────────────────────────────
// MARK: - Piano Constants
// ─────────────────────────────────────────────

let wKW: CGFloat = 56       // White key width
let wKH: CGFloat = 253      // White key height
let bKW: CGFloat = 36       // Black key width
let bKH: CGFloat = 160      // Black key height
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

    private func touchVelocity(_ touch: UITouch) -> UInt8 {
        if touch.maximumPossibleForce > 0, touch.force > 0 {
            let normalized = min(1, touch.force / touch.maximumPossibleForce)
            return UInt8(48 + normalized * 79)
        }
        return 88
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
    @ObservedObject var vm: RecordViewModel
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
        // Let a horizontal drag cancel the touch on a key and start scrolling.
        scroll.canCancelContentTouches = true
        scroll.delaysContentTouches = false
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

    // Container
    static let width: CGFloat        = 392
    static let height: CGFloat       = 45
    static let cornerRadius: CGFloat = 20
    static let strokeWidth: CGFloat  = 1

    // Lines
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

    // Picker (viewport indicator)
    static let pickerWidth: CGFloat        = 46
    static let pickerHeight: CGFloat       = 45
    static let pickerCornerRadius: CGFloat = 14
    static let pickerStrokeWidth: CGFloat  = 2

    /// 8 groups: seven of 7 lines, the last of 3.  Total = 7×7 + 3 = 52.
    private static let groupSizes: [Int] = [7, 7, 7, 7, 7, 7, 7, 3]

    /// The 3rd line of every group (zero-indexed = 2) is a C note.
    private static let cIndexInGroup = 2

    /// Pre-computed (x-center, isC) for each of the 52 lines.
    private static let lineLayout: [(x: CGFloat, isC: Bool)] = {
        var out: [(CGFloat, Bool)] = []
        var x = firstLineInset
        for (gi, count) in groupSizes.enumerated() {
            for li in 0..<count {
                out.append((x, li == cIndexInGroup))
                if li < count - 1 { x += intraGroupStride }
            }
            if gi < groupSizes.count - 1 { x += interGroupStride }
        }
        return out
    }()

    /// Travel range for the picker's center, in container coordinates.
    private static let pickerMinX: CGFloat = pickerWidth / 2
    private static let pickerMaxX: CGFloat = width - pickerWidth / 2

    /// Captured normalized offset at the moment a drag begins, so
    /// `gesture.translation` can be added to a stable starting point.
    @State private var dragStartNorm: CGFloat?

    var body: some View {
        ZStack {
            // Background fill
            RoundedRectangle(
                cornerRadius: Self.cornerRadius,
                style: .continuous
            )
            .fill(Color("Navy"))

            // 52 vertical lines (50 MainPurple + 8 white Cs)
            ForEach(0..<Self.lineLayout.count, id: \.self) { i in
                let cfg = Self.lineLayout[i]
                Capsule()
                    .fill(cfg.isC ? Color.white : Color("MainPurple"))
                    .frame(width: Self.lineWidth, height: Self.lineHeight)
                    .position(x: cfg.x, y: Self.height / 2)
            }

            // Border on top so it remains crisp over the lines
            RoundedRectangle(
                cornerRadius: Self.cornerRadius,
                style: .continuous
            )
            .strokeBorder(Color("MainPurple"), lineWidth: Self.strokeWidth)

            // Viewport picker, on top of everything
            picker
        }
        .frame(width: Self.width, height: Self.height)
        // Clip to the container so the picker can travel flush to the
        // edges without poking past the rounded corners.
        .clipShape(
            RoundedRectangle(
                cornerRadius: Self.cornerRadius,
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
        let centerX = Self.pickerMinX
            + norm * (Self.pickerMaxX - Self.pickerMinX)

        return RoundedRectangle(
            cornerRadius: Self.pickerCornerRadius,
            style: .continuous
        )
        .fill(Color.gray.opacity(0.08))
        .overlay(
            RoundedRectangle(
                cornerRadius: Self.pickerCornerRadius,
                style: .continuous
            )
            .strokeBorder(
                Color("Lavender"),
                lineWidth: Self.pickerStrokeWidth
            )
        )
        .frame(width: Self.pickerWidth, height: Self.pickerHeight)
        .position(x: centerX, y: Self.height / 2)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { gesture in
                    if dragStartNorm == nil {
                        dragStartNorm = scrollState.normalizedOffset
                    }
                    let travel = Self.pickerMaxX - Self.pickerMinX
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
    @ObservedObject var vm: RecordViewModel
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

// MARK: - Glass chrome

enum CreationLayout {
    /// Total block height = scroller + internal spacing + keys.
    static let pianoBlockHeight: CGFloat =
        PianoScroller.height
        + PianoWithScroller.internalSpacing
        + wKH
}

struct SensicGlassCircleButton: View {
    let systemName: String
    /// When true, icon turns white; circle stays Navy + glass (no fill swap).
    var isActive: Bool = false
    var iconColor: Color = Color("MainPurple")
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(isActive ? .white : iconColor)
                .frame(width: 44, height: 44)
                .background {
                    Circle()
                        .fill(Color("Navy"))
                }
                .glassEffect(in: .circle)
        }
        .buttonStyle(.plain)
    }
}

struct SensicGlassSegmentPicker<Tab: Hashable>: View {
    let tabs: [(tab: Tab, title: String)]
    @Binding var selection: Tab

    var body: some View {
        HStack(spacing: 2) {
            ForEach(tabs, id: \.tab) { item in
                Button(item.title) {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selection = item.tab
                    }
                }
                .font(.system(size: 15, weight: .semibold))
                .padding(.vertical, 8)
                .padding(.horizontal, 18)
                .foregroundStyle(selection == item.tab ? .white : Color("tertiary"))
                .background {
                    if selection == item.tab {
                        Capsule().fill(Color("MainPurple"))
                    }
                }
                .clipShape(Capsule())
            }
        }
        .padding(4)
        .glassEffect(.clear.tint(.white.opacity(20)), in: .circle)


    }
}

struct EnterNameGlassAlert: View {
    @Binding var title: String
    let onSave: () -> Void
    let onCancel: () -> Void

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 22) {
            Text("Enter New Name")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)

            TextField("", text: $title, prompt: Text("Punisher").foregroundStyle(.white.opacity(0.45)))
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.12))
                )
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )

            HStack(spacing: 14) {
                glassPillButton("Cancel", action: onCancel)
                glassPillButton("Save", action: onSave)
                    .opacity(canSave ? 1 : 0.45)
                    .disabled(!canSave)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 26)
        .frame(maxWidth: 360)
        .glassEffect(in: .rect(cornerRadius: 28))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.16), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.45), radius: 24, y: 12)
    }

    private func glassPillButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
        }
        .buttonStyle(.plain)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.12))
        )
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
    }
}

struct SensicGlassTransportBar<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
            .glassEffect(in: .capsule)
            .overlay(
                Capsule()
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.22), Color.white.opacity(0.04)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            )
    }
}

// ─────────────────────────────────────────────
// MARK: - TimelineView
// ─────────────────────────────────────────────

struct TimelineView: View {
    let isRecording: Bool
    let noteHistory: [NoteEvent]
    let elapsed: TimeInterval

    private let visibleSeconds: Double = 17
    private let rulerHeight: CGFloat = 28
    private let measureLabels = [1, 5, 9, 13, 17]

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let gridHeight = max(0, height - rulerHeight)
            let playheadX = min(
                CGFloat(elapsed / visibleSeconds) * width,
                max(0, width - 2)
            )

            ZStack(alignment: .topLeading) {
                Color("SpaceBlue")

                timelineRuler(width: width)

                ZStack(alignment: .topLeading) {
                    gridLines(width: width, height: gridHeight)
                    noteBlocks(width: width, height: gridHeight)
                }
                .frame(width: width, height: gridHeight)
                .offset(y: rulerHeight)

                playhead(x: playheadX, gridHeight: gridHeight)
            }
        }
    }

    private func timelineRuler(width: CGFloat) -> some View {
        ZStack(alignment: .leading) {
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 1)
                .offset(y: rulerHeight - 1)

            ForEach(measureLabels, id: \.self) { measure in
                let x = CGFloat(measure) / CGFloat(visibleSeconds) * width
                Text("\(measure)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color("tertiary"))
                    .position(x: x, y: rulerHeight / 2)
            }
        }
        .frame(height: rulerHeight)
    }

    private func gridLines(width: CGFloat, height: CGFloat) -> some View {
        ForEach(0..<18, id: \.self) { index in
            let x = CGFloat(index) / CGFloat(visibleSeconds) * width
            Rectangle()
                .fill(Color("MainPurple").opacity(index % 4 == 0 ? 0.22 : 0.08))
                .frame(width: 1)
                .frame(height: height)
                .offset(x: x)
        }
    }

    private func noteBlocks(width: CGFloat, height: CGFloat) -> some View {
        ForEach(noteHistory.indices, id: \.self) { index in
            let note = noteHistory[index]
            let x = CGFloat(note.timestamp / visibleSeconds) * width
            let barHeight = CGFloat(note.velocity) / 127 * (height * 0.45) + 6
            let lane = CGFloat(note.midiNote - 21) / 88 * (height * 0.55) + 12
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Color("MainPurple").opacity(0.9))
                .frame(
                    width: max(4, CGFloat(max(note.duration, 0.05) / visibleSeconds) * width),
                    height: barHeight
                )
                .offset(x: min(x, width - 4), y: lane)
        }
    }

    private func playhead(x: CGFloat, gridHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            Image(systemName: "diamond.fill")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Color("MainPurple"))
                .frame(height: rulerHeight)

            Rectangle()
                .fill(Color("MainPurple"))
                .frame(width: 1.5, height: gridHeight)
        }
        .offset(x: max(0, x - 0.75))
        .animation(isRecording ? .linear(duration: 0.5) : nil, value: elapsed)
    }
}

// ─────────────────────────────────────────────
// MARK: - NewSessionSheet
// ─────────────────────────────────────────────

struct NewSessionSheet: View {
    @Binding var title: String
    let onStart: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("New Session").font(.headline).foregroundStyle(.white).padding(.top, 8)
            TextField("Session title...", text: $title)
                .padding(14).background(Color("Navy"))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .stroke(Color("MainPurple").opacity(0.3), lineWidth: 0.5))
                .foregroundStyle(.white)
                .onSubmit { if !title.isEmpty { onStart() } }
            HStack(spacing: 12) {
                Button("Cancel", action: onCancel)
                    .frame(maxWidth: .infinity).padding(14)
                    .background(Color("Navy")).foregroundStyle(Color("tertiary"))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                Button("Start") { if !title.isEmpty { onStart() } }
                    .frame(maxWidth: .infinity).padding(14)
                    .background(title.isEmpty ? Color("MainPurple").opacity(0.4) : Color("MainPurple"))
                    .foregroundStyle(.white).fontWeight(.semibold)
                    .clipShape(RoundedRectangle(cornerRadius: 14)).disabled(title.isEmpty)
            }
            Spacer()
        }
        .padding(24).background(Color("SpaceBlue"))
        .presentationDetents([.fraction(0.32)]).presentationDragIndicator(.visible)
    }
}
