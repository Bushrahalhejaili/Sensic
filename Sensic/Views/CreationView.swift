// CreationView.swift
// Sensic

import SwiftUI
import UIKit
import CoreHaptics

// ─────────────────────────────────────────────
// MARK: - Haptic Engine
// ─────────────────────────────────────────────

final class HapticEngine {
    static let shared = HapticEngine()
    private var engine: CHHapticEngine?
    private init() { prepare() }

    func prepare() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        engine = try? CHHapticEngine()
        try? engine?.start()
        engine?.resetHandler = { [weak self] in try? self?.engine?.start() }
    }

    func play(intensity: Float, sharpness: Float) {
        guard let engine,
              CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        let i = CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity)
        let s = CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
        let event = CHHapticEvent(eventType: .hapticTransient, parameters: [i, s], relativeTime: 0)
        guard let pattern = try? CHHapticPattern(events: [event], parameters: []),
              let player  = try? engine.makePlayer(with: pattern) else { return }
        try? player.start(atTime: CHHapticTimeImmediate)
    }
}

// ─────────────────────────────────────────────
// MARK: - Piano Constants
// ─────────────────────────────────────────────


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

let wKW: CGFloat = 56    // white key width
let wKH: CGFloat = 220   // white key height
let bKW: CGFloat = 34    // black key width
let bKH: CGFloat = 140   // black key height

func blackKeyOffset(_ midi: UInt8) -> CGFloat? {
    var whiteCount: CGFloat = 0
    for key in allPianoKeys {
        if key.midi == midi {
            // الأسود يجلس على يمين الأبيض اللي قبله
            return whiteCount * (wKW + 1.5) - bKW / 2
        }
        if !key.isBlack { whiteCount += 1 }
    }
    return nil
}

// ─────────────────────────────────────────────
// MARK: - Piano UIView (handles touch + drawing)
// ─────────────────────────────────────────────

class PianoUIView: UIView {
    var onNoteOn:  ((UInt8) -> Void)?
    var onNoteOff: ((UInt8) -> Void)?
    var activeNotes = Set<UInt8>() {
        didSet { setNeedsDisplay() }
    }

    private var touchToMidi: [UITouch: UInt8] = [:]

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        backgroundColor = .clear
    }
    required init?(coder: NSCoder) { fatalError() }

    // ── Drawing ──────────────────────────────

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }

        // White keys
        for (i, key) in whitePianoKeys.enumerated() {
            let x = CGFloat(i) * (wKW + 1.5)
            let r = CGRect(x: x, y: 0, width: wKW, height: wKH)
            let path = UIBezierPath(roundedRect: r, cornerRadius: 7)

            if activeNotes.contains(key.midi) {
                UIColor(red: 0.6, green: 0.44, blue: 0.76, alpha: 0.45).setFill()
            } else {
                UIColor.white.setFill()
            }
            path.fill()
            UIColor.black.withAlphaComponent(0.1).setStroke()
            path.stroke()

            // C label
            if key.noteName == "C" {
                let attr: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 10, weight: .semibold),
                    .foregroundColor: activeNotes.contains(key.midi)
                        ? UIColor(red: 0.6, green: 0.44, blue: 0.76, alpha: 1)
                        : UIColor.gray
                ]
                let str = NSAttributedString(string: "C\(key.octave)", attributes: attr)
                let sz  = str.size()
                str.draw(at: CGPoint(x: x + (wKW - sz.width) / 2, y: wKH - sz.height - 8))
            }
        }

        // Black keys
        for key in blackPianoKeys {
            guard let x = blackKeyOffset(key.midi) else { continue }
            let r = CGRect(x: x, y: 0, width: bKW, height: bKH)
            let path = UIBezierPath(roundedRect: r, cornerRadius: 6)

            if activeNotes.contains(key.midi) {
                UIColor(red: 0.47, green: 0.31, blue: 0.78, alpha: 1).setFill()
            } else {
                UIColor(white: 0.1, alpha: 1).setFill()
            }
            path.fill()
        }
    }

    // ── Touch ─────────────────────────────────

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches {
            let pt = t.location(in: self)
            if let midi = midiAt(pt) {
                touchToMidi[t] = midi
                onNoteOn?(midi)
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches {
            let pt   = t.location(in: self)
            let prev = touchToMidi[t]
            let curr = midiAt(pt)
            if curr != prev {
                if let p = prev { onNoteOff?(p) }
                if let c = curr { touchToMidi[t] = c; onNoteOn?(c) }
                else             { touchToMidi[t] = nil }
            }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches {
            if let midi = touchToMidi[t] { onNoteOff?(midi) }
            touchToMidi[t] = nil
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEnded(touches, with: event)
    }

    private func midiAt(_ pt: CGPoint) -> UInt8? {
        // Black first
        for key in blackPianoKeys {
            guard let x = blackKeyOffset(key.midi) else { continue }
            if CGRect(x: x, y: 0, width: bKW, height: bKH).contains(pt) { return key.midi }
        }
        // White
        for (i, key) in whitePianoKeys.enumerated() {
            let x = CGFloat(i) * (wKW + 1.5)
            if CGRect(x: x, y: 0, width: wKW, height: wKH).contains(pt) { return key.midi }
        }
        return nil
    }
}

// ─────────────────────────────────────────────
// MARK: - Piano ScrollView (allows simultaneous touch + scroll)
// ─────────────────────────────────────────────

class PianoScrollView: UIScrollView, UIGestureRecognizerDelegate {
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        // السماح للـ pan gesture يبدأ فقط إذا كان أفقياً
        if let pan = gestureRecognizer as? UIPanGestureRecognizer {
            let velocity = pan.velocity(in: self)
            return abs(velocity.x) > abs(velocity.y)
        }
        return true
    }

    func gestureRecognizer(_ g: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith o: UIGestureRecognizer) -> Bool {
        return true
    }
}

// ─────────────────────────────────────────────
// MARK: - Piano ScrollView Wrapper
// ─────────────────────────────────────────────

struct PianoScrollWrapper: UIViewRepresentable {
    @ObservedObject var vm: CreationViewModel
    let hapticIntensity: Float
    let hapticSharpness: Float
    let hapticStyle: CreationView.HapticStyle

    func makeUIView(context: Context) -> UIScrollView {
        let totalW = CGFloat(whitePianoKeys.count) * (wKW + 1.5)

        let piano = PianoUIView(frame: CGRect(x: 0, y: 0, width: totalW, height: wKH))
        piano.onNoteOn  = { midi in
            DispatchQueue.main.async {
                vm.noteOn(midi: midi)
                let i = hapticStyle == .punchy ? min(1, hapticIntensity * 1.4) : hapticIntensity
                HapticEngine.shared.play(intensity: i, sharpness: hapticSharpness)
            }
        }
        piano.onNoteOff = { midi in
            DispatchQueue.main.async { vm.noteOff(midi: midi) }
        }
        context.coordinator.pianoView = piano

        let scroll = PianoScrollView()
        scroll.showsHorizontalScrollIndicator = false
        scroll.showsVerticalScrollIndicator   = false
        scroll.backgroundColor = UIColor(red: 0.05, green: 0.04, blue: 0.1, alpha: 1)
        scroll.canCancelContentTouches = false
        scroll.delaysContentTouches    = false
        scroll.addSubview(piano)
        scroll.contentSize = CGSize(width: totalW, height: wKH)
        context.coordinator.scrollView = scroll
        return scroll
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {
        context.coordinator.pianoView?.activeNotes = vm.activeNotes
    }

    func makeCoordinator() -> Coordinator { Coordinator() }
    class Coordinator {
        var pianoView:  PianoUIView?
        var scrollView: PianoScrollView?
    }
}

// ─────────────────────────────────────────────
// MARK: - CreationView
// ─────────────────────────────────────────────

struct CreationView: View {
    @StateObject private var vm = CreationViewModel()
    @State private var activeTab: Tab = .practice
    @State private var showNewSession = false
    @State private var newTitle = ""
    @State private var hapticIntensity: Float = 0.7
    @State private var hapticSharpness: Float = 0.5
    @State private var hapticStyle: HapticStyle = .smooth

    enum Tab         { case record, practice }
    enum HapticStyle { case smooth, punchy }

    var body: some View {
        ZStack {
            SensicColors.background.ignoresSafeArea()
            VStack(spacing: 0) {
                headerBar
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)

                if activeTab == .record {
                    RecordPanel(
                        vm: vm,
                        hapticIntensity: $hapticIntensity,
                        hapticSharpness: $hapticSharpness,
                        hapticStyle: $hapticStyle
                    )
                } else {
                    PracticePanel(vm: vm)
                }

                Spacer(minLength: 0)

                // Minimap
                HStack(spacing: 1) {
                    ForEach(whitePianoKeys) { key in
                        Rectangle()
                            .fill(vm.activeNotes.contains(key.midi)
                                  ? SensicColors.accentPurple
                                  : SensicColors.accentPurple.opacity(key.noteName == "C" ? 0.25 : 0.07))
                            .frame(height: 4)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(SensicColors.cardNavy)

                // Piano
                PianoScrollWrapper(
                    vm: vm,
                    hapticIntensity: hapticIntensity,
                    hapticSharpness: hapticSharpness,
                    hapticStyle: hapticStyle
                )
                .frame(height: wKH + 10)
                .overlay(alignment: .top) {
                    Rectangle().fill(SensicColors.accentPurple.opacity(0.2)).frame(height: 1)
                }
            }
        }
        .sheet(isPresented: $showNewSession) {
            NewSessionSheet(title: $newTitle) {
                vm.startRecording(title: newTitle)
                newTitle = ""
                showNewSession = false
            } onCancel: { showNewSession = false }
        }
    }

    private var headerBar: some View {
        HStack {
            Button { } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(SensicColors.accentPurple)
            }
            Spacer()
            HStack(spacing: 2) {
                tabBtn("Record",   .record)
                tabBtn("Practice", .practice)
            }
            .padding(4)
            .background(SensicColors.panelNavy)
            .clipShape(Capsule())
            Spacer()
            Button {
                if vm.isRecording { vm.stopRecording() }
                else { showNewSession = true }
            } label: {
                Image(systemName: vm.isRecording ? "checkmark" : "plus")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(vm.isRecording ? Color.green.opacity(0.8) : SensicColors.accentPurple)
                    .clipShape(Circle())
            }
        }
    }

    private func tabBtn(_ label: String, _ tab: Tab) -> some View {
        Button(label) { withAnimation(.easeInOut(duration: 0.15)) { activeTab = tab } }
            .font(.subheadline.weight(.medium))
            .padding(.vertical, 7).padding(.horizontal, 18)
            .background(activeTab == tab ? SensicColors.accentPurple : Color.clear)
            .foregroundStyle(activeTab == tab ? .white : SensicColors.secondaryText)
            .clipShape(Capsule())
    }
}

// ─────────────────────────────────────────────
// MARK: - Record Panel
// ─────────────────────────────────────────────

private struct RecordPanel: View {
    @ObservedObject var vm: CreationViewModel
    @Binding var hapticIntensity: Float
    @Binding var hapticSharpness: Float
    @Binding var hapticStyle: CreationView.HapticStyle

    var body: some View {
        VStack(spacing: 12) {
            TimelineView(isRecording: vm.isRecording, noteHistory: vm.noteHistory, elapsed: vm.elapsedSeconds)
                .frame(height: 90)
                .padding(.horizontal, 16)

            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 14) {
                    sliderRow("Haptic intensity", value: $hapticIntensity)
                    sliderRow("Haptic Sharpness", value: $hapticSharpness)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Haptic style").font(.system(size: 12)).foregroundStyle(SensicColors.secondaryText)
                    styleBtn("Smooth", .smooth)
                    styleBtn("Punchy", .punchy)
                }
                .frame(width: 100)
            }
            .padding(16)
            .background(SensicColors.panelNavy)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
            .padding(.horizontal, 16)

            HStack {
                if vm.isRecording {
                    Text(vm.formattedTime)
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                    Spacer()
                    Button("Discard") { vm.discardRecording() }
                        .font(.subheadline).foregroundStyle(SensicColors.secondaryText)
                } else {
                    Spacer()
                    Text("Tap + to start recording").font(.subheadline).foregroundStyle(SensicColors.secondaryText)
                    Spacer()
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.top, 8)
    }

    private func sliderRow(_ label: String, value: Binding<Float>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.system(size: 12)).foregroundStyle(SensicColors.secondaryText)
            Slider(value: value, in: 0...1).tint(SensicColors.accentPurple)
        }
    }

    private func styleBtn(_ label: String, _ style: CreationView.HapticStyle) -> some View {
        Button(label) { hapticStyle = style }
            .font(.subheadline.weight(.medium))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(hapticStyle == style ? SensicColors.accentPurple : Color.clear)
            .foregroundStyle(hapticStyle == style ? .white : SensicColors.secondaryText)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(
                hapticStyle == style ? Color.clear : SensicColors.accentPurple.opacity(0.3),
                lineWidth: 0.5))
    }
}

// ─────────────────────────────────────────────
// MARK: - Timeline
// ─────────────────────────────────────────────

private struct TimelineView: View {
    let isRecording: Bool
    let noteHistory: [NoteEvent]
    let elapsed: TimeInterval
    private let visibleSeconds: Double = 17

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 14).fill(SensicColors.panelNavy)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
                ForEach(1..<18) { i in
                    Rectangle().fill(Color.white.opacity(0.05)).frame(width: 0.5)
                        .offset(x: CGFloat(i) / CGFloat(visibleSeconds) * w)
                }
                ForEach(noteHistory.indices, id: \.self) { i in
                    let note = noteHistory[i]
                    let x    = CGFloat(note.timestamp / visibleSeconds) * w
                    let bh   = CGFloat(note.velocity) / 127 * (h * 0.5) + 4
                    let lane = CGFloat(note.midiNote - 21) / 88 * (h * 0.6) + 10
                    RoundedRectangle(cornerRadius: 2)
                        .fill(SensicColors.accentPurple.opacity(0.85))
                        .frame(width: max(4, CGFloat(max(note.duration, 0.05) / visibleSeconds) * w), height: bh)
                        .offset(x: min(x, w - 4), y: lane - h * 0.3)
                }
                if isRecording {
                    Rectangle().fill(SensicColors.accentPurple).frame(width: 1.5)
                        .offset(x: min(CGFloat(elapsed / visibleSeconds) * w, w - 2))
                        .animation(.linear(duration: 0.5), value: elapsed)
                }
            }
            .clipped()
        }
    }
}

// ─────────────────────────────────────────────
// MARK: - Practice Panel
// ─────────────────────────────────────────────

private struct PracticePanel: View {
    @ObservedObject var vm: CreationViewModel

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                statCard("Sessions", "\(vm.sessions.count)")
                statCard("Notes",    "\(vm.noteHistory.count)")
                statCard("Active",   "\(vm.activeNotes.count)")
            }
            .padding(.horizontal, 16)

            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(vm.sessions) { session in
                        SessionRow(session: session) { vm.deleteSession(id: session.id) }
                    }
                    if vm.sessions.isEmpty {
                        Text("No sessions yet — tap + to start")
                            .font(.subheadline).foregroundStyle(SensicColors.secondaryText).padding(.top, 30)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.top, 8)
    }

    private func statCard(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 11)).foregroundStyle(SensicColors.secondaryText)
            Text(value).font(.system(size: 22, weight: .bold)).foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(SensicColors.panelNavy)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
    }
}

// ─────────────────────────────────────────────
// MARK: - Session Row
// ─────────────────────────────────────────────

private struct SessionRow: View {
    let session: PracticeSession
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10)
                .fill(SensicColors.accentPurple.opacity(0.12)).frame(width: 42, height: 42)
                .overlay(Image(systemName: "music.note").foregroundStyle(SensicColors.accentPurple))
            VStack(alignment: .leading, spacing: 3) {
                Text(session.title).font(.subheadline.weight(.medium)).foregroundStyle(.white)
                Text("\(session.noteEvents.count) notes · \(Int(session.durationSeconds))s")
                    .font(.caption).foregroundStyle(SensicColors.secondaryText)
            }
            Spacer()
            Text("\(Int(session.accuracy * 100))%")
                .font(.caption.bold()).foregroundStyle(SensicColors.accentPurple)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(SensicColors.accentPurple.opacity(0.12)).clipShape(Capsule())
            Button(action: onDelete) {
                Image(systemName: "trash").font(.system(size: 14)).foregroundStyle(SensicColors.secondaryText)
            }
        }
        .padding(14)
        .background(SensicColors.panelNavy)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.06), lineWidth: 0.5))
    }
}

// ─────────────────────────────────────────────
// MARK: - New Session Sheet
// ─────────────────────────────────────────────

private struct NewSessionSheet: View {
    @Binding var title: String
    let onStart: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("New Session").font(.headline).foregroundStyle(.white).padding(.top, 8)
            TextField("Session title...", text: $title)
                .padding(14).background(SensicColors.cardNavy)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .stroke(SensicColors.accentPurple.opacity(0.3), lineWidth: 0.5))
                .foregroundStyle(.white)
                .onSubmit { if !title.isEmpty { onStart() } }
            HStack(spacing: 12) {
                Button("Cancel", action: onCancel)
                    .frame(maxWidth: .infinity).padding(14)
                    .background(SensicColors.cardNavy).foregroundStyle(SensicColors.secondaryText)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                Button("Start") { if !title.isEmpty { onStart() } }
                    .frame(maxWidth: .infinity).padding(14)
                    .background(title.isEmpty ? SensicColors.accentPurple.opacity(0.4) : SensicColors.accentPurple)
                    .foregroundStyle(.white).fontWeight(.semibold)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .disabled(title.isEmpty)
            }
            Spacer()
        }
        .padding(24).background(SensicColors.panelNavy)
        .presentationDetents([.fraction(0.32)])
        .presentationDragIndicator(.visible)
    }
}

// ─────────────────────────────────────────────
// MARK: - Preview
// ─────────────────────────────────────────────

#Preview { CreationView() }
