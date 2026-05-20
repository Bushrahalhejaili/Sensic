//
//  CreationView.swift
//  Sensic
//

import SwiftUI
import CoreHaptics

// MARK: - Haptic Engine

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
              let player = try? engine.makePlayer(with: pattern) else { return }
        try? player.start(atTime: CHHapticTimeImmediate)
    }
}

// MARK: - CreationView

struct CreationView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var store: RecordingsStore
    var onSavedToRecordings: (() -> Void)?

    @StateObject private var recordVM = RecordViewModel()
    @StateObject private var practiceVM = PracticeViewModel()
    @StateObject private var scrollState = PianoScrollState()

    @State private var activeTab: Tab = .record
    @State private var showSettings = false
    @State private var showSaveDialog = false
    @State private var showSaveError = false
    @State private var showExitDialog = false
    @State private var saveErrorMessage = ""
    @State private var saveTitle = ""
    @State private var saveNavigatesToRecordings = true

    @State private var hapticIntensity: Float = 0.7
    @State private var hapticSharpness: Float = 0.5
    @State private var hapticStyle: HapticStyle = .smooth

    enum Tab: Hashable { case record, practice }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 8)

                if activeTab == .record {
                    recordWorkspace
                } else {
                    PracticeView(vm: practiceVM)
                }
            }

            if showSaveDialog {
                Color.black.opacity(0.55)
                    .ignoresSafeArea()
                    .transition(.opacity)

                EnterNameGlassAlert(
                    title: $saveTitle,
                    onSave: {
                        showSaveDialog = false
                        persistRecording(title: saveTitle, navigateToRecordings: saveNavigatesToRecordings)
                    },
                    onCancel: { showSaveDialog = false }
                )
                .padding(.horizontal, 24)
                .transition(.scale(scale: 0.94).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.86), value: showSaveDialog)
        .preferredColorScheme(.dark)
        .toolbar(.hidden, for: .navigationBar)
        .alert("Cannot save", isPresented: $showSaveError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveErrorMessage)
        }
        .confirmationDialog(
            "Unsaved recording",
            isPresented: $showExitDialog,
            titleVisibility: .visible
        ) {
            Button("Save") {
                saveNavigatesToRecordings = false
                prepareSaveTitle()
                showSaveDialog = true
            }
            Button("Delete", role: .destructive) {
                recordVM.discardRecording()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Do you want to save this recording or delete it?")
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(spacing: 12) {
            glassCircleButton(
                icon: "chevron.left",
                iconSize: 20,
                iconColor: .white,
                action: attemptGoBack
            )

            Spacer(minLength: 0)

            segmentPicker

            Spacer(minLength: 0)

            if activeTab == .record {
                glassCircleButton(
                    icon: "checkmark",
                    iconSize: 20,
                    iconColor: .white,
                    action: presentSaveSheet
                )
            } else {
                Color.clear
                    .frame(width: 44, height: 44)
                    .accessibilityHidden(true)
            }
        }
    }

    // Custom segmented control — solid Navy capsule with a MainPurple
    // thumb that slides between segments. Avoids UISegmentedControl's
    // translucent vibrancy overlay (which was lightening the Navy)
    // and its legacy-mode rendering glitches.
    @Namespace private var segNamespace

    private var segmentPicker: some View {
        HStack(spacing: 0) {
            segmentLabel("Record",   tab: .record)
            segmentLabel("Practice", tab: .practice)
        }
        .padding(3)
        .background(Color("Navy"))
        .clipShape(Capsule())
        .frame(width: 214, height: 44)
    }

    private func segmentLabel(_ title: String, tab: Tab) -> some View {
        let selected = activeTab == tab
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                activeTab = tab
            }
        } label: {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background {
                    if selected {
                        Capsule()
                            .fill(Color("MainPurple"))
                            .matchedGeometryEffect(
                                id: "segThumb", in: segNamespace)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Workspace (matches Figma)

    private var recordWorkspace: some View {
        VStack(spacing: 0) {
            toolBar
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 10)

            if showSettings {
                HapticControlsView(
                    intensity: $hapticIntensity,
                    sharpness: $hapticSharpness,
                    style: $hapticStyle
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            MainTimelineView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .layoutPriority(1)

            PianoWithMinimap(
                vm: recordVM,
                scrollState: scrollState,
                hapticIntensity: hapticIntensity,
                hapticSharpness: hapticSharpness,
                hapticStyle: hapticStyle
            )
            .frame(height: CreationLayout.pianoBlockHeight)
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.86), value: showSettings)
    }

    // MARK: - Toolbar (redesigned for iOS 26 Liquid Glass)

    private var toolBar: some View {
        HStack(spacing: 0) {
            // Left cluster: undo, redo, controls (10 between each)
            HStack(spacing: 10) {
                glassCircleButton(
                    icon: "arrow.uturn.backward",
                    iconSize: 20,
                    enabled: recordVM.canUndo,
                    action: { recordVM.undo() }
                )

                glassCircleButton(
                    icon: "arrow.uturn.forward",
                    iconSize: 20,
                    enabled: recordVM.canRedo,
                    action: { recordVM.redo() }
                )

                glassCircleButton(
                    icon: "slider.horizontal.3",
                    iconSize: 20,
                    action: {
                        withAnimation(.spring(response: 0.38,
                                              dampingFraction: 0.86)) {
                            showSettings.toggle()
                        }
                    }
                )
            }

            // 47 between controls and playback bar (min — fills extra
            // space on wider screens so the bar hugs the right edge).
            Spacer(minLength: 47)

            transportBar
        }
    }

    // Shared angular gradient — simulates the light reflection on the
    // glass rim. Used by all toolbar buttons (circle + capsule).
    private var glassShineGradient: AngularGradient {
        AngularGradient(
            gradient: Gradient(colors: [
                Color.black.opacity(0.4),
                Color.white.opacity(0.6),
                Color.black.opacity(0.2),
                Color.white.opacity(0.9),
                Color.black.opacity(0.2),
                Color.black.opacity(0.4)
            ]),
            center: .center
        )
    }

    // 44×44 Liquid Glass circle button.
    // Layers: Navy fill (95%) → angular-gradient stroke rim → clear
    // interactive glass on top.
    private func glassCircleButton(
        icon: String,
        iconSize: CGFloat,
        iconColor: Color = Color("MainPurple"),
        enabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(Color("Navy").opacity(0.95))
                        .overlay(
                            Circle().strokeBorder(
                                glassShineGradient,
                                lineWidth: 0.4
                            )
                        )
                        .glassEffect(.clear)
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .opacity(enabled ? 1 : 0.35)
        .disabled(!enabled)
    }

    // MARK: - Transport bar (171×44 Liquid Glass capsule)

    private var transportBar: some View {
        HStack(spacing: 4) {
            transportIcon("backward.fill") {}            // rewind back
            transportIcon("forward.fill")  {}            // rewind fwd

            transportIcon("stop.fill") {
                recordVM.stopPlayback()
                if recordVM.isRecording {
                    _ = recordVM.stopRecording()
                }
            }

            transportIcon(recordVM.isPlaying ? "pause.fill" : "play.fill") {
                recordVM.togglePlayback()
            }
            .opacity(recordVM.canSave ? 1 : 0.35)
            .disabled(!recordVM.canSave)

            recordIconButton
        }
        .frame(width: 171, height: 44)
        .background(
            Capsule()
                .fill(Color("Navy").opacity(0.95))
                .overlay(
                    Capsule().strokeBorder(
                        glassShineGradient,
                        lineWidth: 0.4
                    )
                )
                .glassEffect(.clear.interactive())
        )
    }

    private func transportIcon(
        _ name: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: name)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
    }

    private var recordIconButton: some View {
        Button(action: toggleRecording) {
            Image(systemName: "circle.fill")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(recordVM.isRecording
                                 ? Color("RecordingRed") : .white)
        }
        .buttonStyle(.plain)
    }

    private func toggleRecording() {
        if recordVM.isRecording {
            _ = recordVM.stopRecording()
        } else {
            recordVM.startRecording()
        }
    }

    // MARK: - Navigation & save

    private func attemptGoBack() {
        if activeTab == .practice {
            dismiss()
            return
        }

        if recordVM.hasUnsavedWork {
            showExitDialog = true
        } else {
            dismiss()
        }
    }

    private func presentSaveSheet() {
        saveNavigatesToRecordings = true
        if recordVM.isRecording {
            _ = recordVM.stopRecording()
        }

        guard recordVM.canSave else {
            saveErrorMessage = "Nothing recorded yet. Record notes before saving."
            showSaveError = true
            return
        }

        prepareSaveTitle()
        showSaveDialog = true
    }

    private func prepareSaveTitle() {
        saveTitle = recordVM.sessionTitle
    }

    private func persistRecording(title: String, navigateToRecordings: Bool) {
        if recordVM.isRecording {
            _ = recordVM.stopRecording()
        }

        guard recordVM.canSave else {
            saveErrorMessage = "Nothing recorded yet. Record notes before saving."
            showSaveError = true
            return
        }

        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        store.savePiece(
            title: trimmed,
            duration: recordVM.sessionDuration,
            noteEvents: recordVM.eventsForPlayback
        )
        store.showToast("Saved to Recordings")
        recordVM.discardRecording()

        if navigateToRecordings {
            dismiss()
            onSavedToRecordings?()
        } else {
            dismiss()
        }
    }
}

#Preview {
    CreationView(store: .previewInstance())
//        .preferredColorScheme(.dark)
}
