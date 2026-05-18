// CreationView.swift
// Sensic

import SwiftUI
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
// MARK: - CreationView
// ─────────────────────────────────────────────

struct CreationView: View {
    @StateObject private var recordVM   = RecordViewModel()
    @StateObject private var practiceVM = PracticeViewModel()
    @State private var activeTab: Tab   = .record
    @State private var showNewSession   = false
    @State private var newTitle         = ""
    @State private var hapticIntensity: Float = 0.7
    @State private var hapticSharpness: Float = 0.5
    @State private var hapticStyle: HapticStyle = .smooth

    enum Tab { case record, practice }

    var body: some View {
        ZStack {
            SensicColors.background.ignoresSafeArea()
            VStack(spacing: 0) {
                headerBar
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)

                if activeTab == .record {
                    recordContent
                } else {
                    PracticeView(vm: practiceVM)
                }
            }
        }
        .sheet(isPresented: $showNewSession) {
            NewSessionSheet(title: $newTitle) {
                recordVM.startRecording(title: newTitle)
                newTitle = ""
                showNewSession = false
            } onCancel: { showNewSession = false }
        }
    }

    // ─────────────────────────────────────────
    // MARK: - Header
    // ─────────────────────────────────────────

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
                if recordVM.isRecording {
                    if let session = recordVM.stopRecording() {
                        practiceVM.addSession(session)
                    }
                } else {
                    showNewSession = true
                }
            } label: {
                Image(systemName: recordVM.isRecording ? "checkmark" : "plus")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(recordVM.isRecording ? Color.green.opacity(0.8) : SensicColors.accentPurple)
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

    // ─────────────────────────────────────────
    // MARK: - Record Content
    // ─────────────────────────────────────────

    private var recordContent: some View {
        VStack(spacing: 12) {
            TimelineView(
                isRecording: recordVM.isRecording,
                noteHistory: recordVM.noteHistory,
                elapsed: recordVM.elapsedSeconds
            )
            .frame(height: 90)
            .padding(.horizontal, 16)

            HapticControlsView(
                intensity: $hapticIntensity,
                sharpness: $hapticSharpness,
                style: $hapticStyle
            )
            .padding(.horizontal, 16)

            HStack {
                if recordVM.isRecording {
                    Text(recordVM.formattedTime)
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                    Spacer()
                    Button("Discard") { recordVM.discardRecording() }
                        .font(.subheadline).foregroundStyle(SensicColors.secondaryText)
                } else {
                    Spacer()
                    Button { showNewSession = true } label: {
                        Label("Start recording", systemImage: "record.circle")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(SensicColors.accentPurple)
                    }
                    Spacer()
                }
            }
            .padding(.horizontal, 20)

            Spacer(minLength: 0)

            PianoWithMinimap(
                vm: recordVM,
                hapticIntensity: hapticIntensity,
                hapticSharpness: hapticSharpness,
                hapticStyle: hapticStyle
            )
        }
        .padding(.top, 8)
    }
}

#Preview { CreationView() }
