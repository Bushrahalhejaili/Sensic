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
    var onNoteOn:  ((UInt8) -> Void)?
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
            if let m = midiAt(t.location(in: self)) { touchToMidi[t] = m; onNoteOn?(m) }
        }
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches {
            let curr = midiAt(t.location(in: self)); let prev = touchToMidi[t]
            if curr != prev {
                if let p = prev { onNoteOff?(p) }
                if let c = curr { touchToMidi[t] = c; onNoteOn?(c) } else { touchToMidi[t] = nil }
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
    let hapticIntensity: Float
    let hapticSharpness: Float
    let hapticStyle: HapticStyle

    func makeUIView(context: Context) -> PianoScrollUIView {
        let totalW = CGFloat(whitePianoKeys.count) * (wKW + 1.5)
        let piano  = PianoUIView(frame: CGRect(x: 0, y: 0, width: totalW, height: wKH))
        piano.onNoteOn = { midi in
            DispatchQueue.main.async {
                vm.noteOn(midi: midi)
                let i = hapticStyle == .punchy ? min(1, hapticIntensity * 1.4) : hapticIntensity
                HapticEngine.shared.play(intensity: i, sharpness: hapticSharpness)
            }
        }
        piano.onNoteOff = { midi in DispatchQueue.main.async { vm.noteOff(midi: midi) } }
        context.coordinator.pianoView = piano

        let scroll = PianoScrollUIView()
        scroll.showsHorizontalScrollIndicator = false
        scroll.showsVerticalScrollIndicator   = false
        scroll.backgroundColor = UIColor(red: 0.05, green: 0.04, blue: 0.1, alpha: 1)
        scroll.canCancelContentTouches = false
        scroll.delaysContentTouches    = false
        scroll.addSubview(piano)
        scroll.contentSize = CGSize(width: totalW, height: wKH)
        return scroll
    }

    func updateUIView(_ uiView: PianoScrollUIView, context: Context) {
        context.coordinator.pianoView?.activeNotes = vm.activeNotes
    }

    func makeCoordinator() -> Coordinator { Coordinator() }
    class Coordinator { var pianoView: PianoUIView? }
}

// ─────────────────────────────────────────────
// MARK: - PianoWithMinimap
// ─────────────────────────────────────────────

struct PianoWithMinimap: View {
    @ObservedObject var vm: RecordViewModel
    let hapticIntensity: Float
    let hapticSharpness: Float
    let hapticStyle: HapticStyle

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 1) {
                ForEach(whitePianoKeys) { key in
                    Rectangle()
                        .fill(vm.activeNotes.contains(key.midi)
                              ? SensicColors.accentPurple
                              : SensicColors.accentPurple.opacity(key.noteName == "C" ? 0.25 : 0.07))
                        .frame(height: 4)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 5)
            .background(SensicColors.cardNavy)
            .animation(.easeOut(duration: 0.05), value: vm.activeNotes)

            PianoSection(vm: vm, hapticIntensity: hapticIntensity,
                         hapticSharpness: hapticSharpness, hapticStyle: hapticStyle)
                .frame(height: wKH + 10)
                .overlay(alignment: .top) {
                    Rectangle().fill(SensicColors.accentPurple.opacity(0.2)).frame(height: 1)
                }
        }
        .background(SensicColors.cardNavy)
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

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width; let h = geo.size.height
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 14).fill(SensicColors.panelNavy)
                    .overlay(RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.06), lineWidth: 0.5))
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
    }

    private func sliderRow(_ label: String, value: Binding<Float>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.system(size: 12)).foregroundStyle(SensicColors.secondaryText)
            Slider(value: value, in: 0...1).tint(SensicColors.accentPurple)
        }
    }

    private func styleBtn(_ label: String, _ s: HapticStyle) -> some View {
        Button(label) { style = s }
            .font(.subheadline.weight(.medium)).frame(maxWidth: .infinity).padding(.vertical, 8)
            .background(style == s ? SensicColors.accentPurple : Color.clear)
            .foregroundStyle(style == s ? .white : SensicColors.secondaryText)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(style == s ? Color.clear : SensicColors.accentPurple.opacity(0.3), lineWidth: 0.5))
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
                    .clipShape(RoundedRectangle(cornerRadius: 14)).disabled(title.isEmpty)
            }
            Spacer()
        }
        .padding(24).background(SensicColors.panelNavy)
        .presentationDetents([.fraction(0.32)]).presentationDragIndicator(.visible)
    }
}
