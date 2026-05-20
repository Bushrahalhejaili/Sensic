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
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(spacing: 12) {
            SensicGlassCircleButton(
                systemName: "chevron.left",
                iconColor: Color("MainPurple"),
                action: attemptGoBack
            )

            Spacer(minLength: 0)

            SensicGlassSegmentPicker(
                tabs: [(.record, "Record"), (.practice, "Practice")],
                selection: $activeTab
            )

            Spacer(minLength: 0)

            if activeTab == .record {
                SensicGlassCircleButton(
                    systemName: "checkmark",
                    iconColor: Color("MainPurple"),
                    action: presentSaveSheet
                )
            } else {
                Color.clear
                    .frame(width: 44, height: 44)
                    .accessibilityHidden(true)
            }
        }
    }

    // MARK: - Workspace (matches Figma)

    private var recordWorkspace: some View {
        VStack(spacing: 0) {
            toolBar
                .padding(.horizontal, 16)
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

    private var toolBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 10) {
                SensicGlassCircleButton(
                    systemName: "arrow.uturn.backward",
                    iconColor: Color("MainPurple"),
                    action: { recordVM.undo() }
                )
                .opacity(recordVM.canUndo ? 1 : 0.35)
                .disabled(!recordVM.canUndo)

                SensicGlassCircleButton(
                    systemName: "arrow.uturn.forward",
                    iconColor: Color("MainPurple"),
                    action: { recordVM.redo() }
                )
                .opacity(recordVM.canRedo ? 1 : 0.35)
                .disabled(!recordVM.canRedo)
            }

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                SensicGlassCircleButton(
                    systemName: "slider.horizontal.3",
                    isActive: showSettings,
                    action: {
                        withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                            showSettings.toggle()
                        }
                    }
                )

                transportBar
            }
        }
    }

    private var transportBar: some View {
        SensicGlassTransportBar {
            HStack(spacing: 18) {
                transportIcon("backward.end.fill") {}
                transportIcon("forward.end.fill") {}

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

                Button {
                    toggleRecording()
                } label: {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(recordVM.isRecording ? Color("RecordingRed") : .white)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func transportIcon(_ name: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
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
}
