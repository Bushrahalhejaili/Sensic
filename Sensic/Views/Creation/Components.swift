// CreationComponents.swift
// Sensic

import SwiftUI
import UIKit

// ─────────────────────────────────────────────
// MARK: - Piano Constants
// ─────────────────────────────────────────────

let wKW: CGFloat = 56
let wKH: CGFloat = 220
let bKW: CGFloat = 34
let bKH: CGFloat = 140

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
    for midi in 21...108 {
        result.append(PianoKeyModel(
            midi:     UInt8(midi),
            isBlack:  _blackPat[(midi - 21 + 9) % 12],
            noteName: names[(midi + 3) % 12],
            octave:   (midi + 3) / 12 - 1
        ))
    }
    return result
}

let allPianoKeys   = buildPianoKeys()
let whitePianoKeys = allPianoKeys.filter { !$0.isBlack }
let blackPianoKeys = allPianoKeys.filter {  $0.isBlack }

func blackKeyOffset(_ midi: UInt8) -> CGFloat? {
    var whiteCount: CGFloat = 0
    for key in allPianoKeys {
        if key.midi == midi { return whiteCount * (wKW + 1.5) - bKW / 2 }
        if !key.isBlack { whiteCount += 1 }
    }
    return nil
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
        // White keys
        for (i, key) in whitePianoKeys.enumerated() {
            let x = CGFloat(i) * (wKW + 1.5)
            let r = CGRect(x: x, y: 0, width: wKW, height: wKH)
            let path = UIBezierPath(roundedRect: r, cornerRadius: 7)
            (activeNotes.contains(key.midi)
                ? UIColor(red: 0.6, green: 0.44, blue: 0.76, alpha: 0.45)
                : UIColor.white).setFill()
            path.fill()
            UIColor.black.withAlphaComponent(0.1).setStroke()
            path.lineWidth = 0.5; path.stroke()
            if key.noteName == "C" {
                let attr: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 11, weight: .semibold),
                    .foregroundColor: activeNotes.contains(key.midi)
                        ? UIColor(red: 0.6, green: 0.44, blue: 0.76, alpha: 1) : UIColor.gray
                ]
                let str = NSAttributedString(string: "C\(key.octave)", attributes: attr)
                let sz  = str.size()
                str.draw(at: CGPoint(x: x + (wKW - sz.width) / 2, y: wKH - sz.height - 10))
            }
        }
        // Black keys
        for key in blackPianoKeys {
            guard let x = blackKeyOffset(key.midi) else { continue }
            let path = UIBezierPath(roundedRect: CGRect(x: x, y: 0, width: bKW, height: bKH), cornerRadius: 6)
            (activeNotes.contains(key.midi)
                ? UIColor(red: 0.47, green: 0.31, blue: 0.78, alpha: 1)
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
            if CGRect(x: CGFloat(i) * (wKW + 1.5), y: 0, width: wKW, height: wKH).contains(pt) { return key.midi }
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
    let hapticIntensity: Float
    let hapticSharpness: Float
    let hapticStyle: HapticStyle

    func makeUIView(context: Context) -> PianoScrollUIView {
        let totalW = PianoScrollState.totalContentWidth
        let piano = PianoUIView(frame: CGRect(x: 0, y: 0, width: totalW, height: wKH))
        piano.onNoteOn = { midi, velocity in
            DispatchQueue.main.async {
                vm.noteOn(midi: midi, velocity: velocity)
                let i = hapticStyle == .punchy ? min(1, hapticIntensity * 1.4) : hapticIntensity
                HapticEngine.shared.play(intensity: i, sharpness: hapticSharpness)
            }
        }
        piano.onNoteOff = { midi in DispatchQueue.main.async { vm.noteOff(midi: midi) } }
        context.coordinator.pianoView = piano

        let scroll = PianoScrollUIView()
        scroll.showsHorizontalScrollIndicator = false
        scroll.showsVerticalScrollIndicator = false
        scroll.backgroundColor = .clear
        scroll.canCancelContentTouches = false
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
// MARK: - PianoWithMinimap
// ─────────────────────────────────────────────

struct PianoWithMinimap: View {
    @ObservedObject var vm: RecordViewModel
    @ObservedObject var scrollState: PianoScrollState
    let hapticIntensity: Float
    let hapticSharpness: Float
    let hapticStyle: HapticStyle

    @State private var dragStartNormalized: CGFloat = 0
    @State private var isDraggingViewport = false

    var body: some View {
        VStack(spacing: 0) {
            minimapNavigator
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 8)

            PianoSection(
                vm: vm,
                scrollState: scrollState,
                hapticIntensity: hapticIntensity,
                hapticSharpness: hapticSharpness,
                hapticStyle: hapticStyle
            )
            .frame(height: wKH + 10)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color("MainPurple").opacity(0.2))
                    .frame(height: 1)
            }
        }
    }

    private var minimapNavigator: some View {
        GeometryReader { geo in
            let inset: CGFloat = 6
            let mapWidth = geo.size.width - inset * 2
            let barHeight = geo.size.height - inset * 2
            let viewportRatio = min(1, scrollState.viewportWidth / PianoScrollState.totalContentWidth)
            let viewportWidth = max(52, mapWidth * viewportRatio)
            let travel = max(0, mapWidth - viewportWidth)
            let viewportX = inset + travel * scrollState.normalizedOffset

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color(red: 8 / 255, green: 10 / 255, blue: 22 / 255))
                    .overlay(
                        Capsule()
                            .stroke(Color("MainPurple").opacity(0.85), lineWidth: 1.5)
                    )

                HStack(spacing: 2) {
                    ForEach(whitePianoKeys) { key in
                        Capsule()
                            .fill(minimapKeyColor(for: key))
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, inset + 8)
                .padding(.vertical, inset + 4)
                .frame(height: barHeight)

                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.white.opacity(0.55), lineWidth: 1.5)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                    )
                    .frame(width: viewportWidth, height: barHeight)
                    .offset(x: viewportX)
                    .shadow(color: Color("MainPurple").opacity(0.35), radius: 6, y: 0)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                guard travel > 0 else { return }
                                if !isDraggingViewport {
                                    isDraggingViewport = true
                                    dragStartNormalized = scrollState.normalizedOffset
                                }
                                let delta = value.translation.width / travel
                                scrollState.setNormalizedOffset(
                                    min(1, max(0, dragStartNormalized + delta)),
                                    animated: false
                                )
                            }
                            .onEnded { _ in
                                isDraggingViewport = false
                            }
                    )
            }
            .contentShape(Capsule())
            .onTapGesture { location in
                guard travel > 0 else { return }
                let localX = location.x - inset - viewportWidth / 2
                let target = min(1, max(0, localX / travel))
                scrollState.setNormalizedOffset(target, animated: true)
            }
        }
        .frame(height: 44)
        .animation(.easeOut(duration: 0.05), value: vm.activeNotes)
    }

    private func minimapKeyColor(for key: PianoKeyModel) -> Color {
        if vm.activeNotes.contains(key.midi) {
            return Color("MainPurple")
        }
        if key.noteName == "C" {
            return Color.white.opacity(0.95)
        }
        return Color("MainPurple").opacity(0.72)
    }
}

// MARK: - Glass chrome

enum CreationLayout {
    static let pianoBlockHeight: CGFloat = wKH + 10 + 44 + 12
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
// MARK: - HapticControlsView
// ─────────────────────────────────────────────

enum HapticStyle { case smooth, punchy }

struct HapticControlsView: View {
    @Binding var intensity: Float
    @Binding var sharpness: Float
    @Binding var style: HapticStyle

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 14) {
                sliderRow("Haptic intensity", value: $intensity)
                sliderRow("Haptic Sharpness", value: $sharpness)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Haptic style").font(.system(size: 12)).foregroundStyle(Color("tertiary"))
                styleBtn("Smooth", .smooth)
                styleBtn("Punchy", .punchy)
            }
            .frame(width: 100)
        }
        .padding(16)
        .background(Color("SpaceBlue"))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
    }

    private func sliderRow(_ label: String, value: Binding<Float>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.system(size: 12)).foregroundStyle(Color("tertiary"))
            Slider(value: value, in: 0...1).tint(Color("MainPurple"))
        }
    }

    private func styleBtn(_ label: String, _ s: HapticStyle) -> some View {
        Button(label) { style = s }
            .font(.subheadline.weight(.medium)).frame(maxWidth: .infinity).padding(.vertical, 8)
            .background(style == s ? Color("MainPurple") : Color.clear)
            .foregroundStyle(style == s ? .white : Color("tertiary"))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(style == s ? Color.clear : Color("MainPurple").opacity(0.3), lineWidth: 0.5))
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
