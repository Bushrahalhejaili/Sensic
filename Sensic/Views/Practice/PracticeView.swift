// PracticeView.swift
// Sensic

import SwiftUI
import Combine

struct PracticeView: View {
    @ObservedObject var vm: PracticeViewModel
    @StateObject private var recordVM = RecordViewModel()
    @StateObject private var scrollState = PianoScrollState()
    @StateObject private var visualizer = PracticeVisualizerModel()

    @State private var hapticIntensity: Float = 0.7
    @State private var hapticSharpness: Float = 0.5
    @State private var hapticStyle: HapticStyle = .smooth

    var body: some View {
        VStack(spacing: 12) {
            PracticeNoteVisualizerGrid(model: visualizer)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 16)
            .layoutPriority(1)

            HapticControlsView(
                intensity: $hapticIntensity,
                sharpness: $hapticSharpness,
                style: $hapticStyle
            )
            .padding(.horizontal, 16)

            PianoWithMinimap(
                vm: recordVM,
                scrollState: scrollState,
                hapticIntensity: hapticIntensity,
                hapticSharpness: hapticSharpness,
                hapticStyle: hapticStyle
            )
            .frame(height: CreationLayout.pianoBlockHeight)
        }
        .padding(.top, 4)
        .onAppear {
            refreshVisualizer()
        }
        .onReceive(Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()) { _ in
            refreshVisualizer()
        }
        .onChange(of: recordVM.activeNotes) { _, _ in
            refreshVisualizer()
        }
        .onChange(of: scrollState.offset) { _, _ in
            refreshVisualizer()
        }
        .onChange(of: scrollState.viewportWidth) { _, _ in
            refreshVisualizer()
        }
    }

    private func refreshVisualizer() {
        visualizer.update(
            activeNotes: recordVM.activeNotes,
            scrollState: scrollState,
            velocities: recordVM.activeNoteVelocities
        )
    }
}
