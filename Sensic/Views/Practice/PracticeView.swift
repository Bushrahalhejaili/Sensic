// PracticeView.swift
// Sensic

import SwiftUI
import Combine

struct PracticeView: View {
    @ObservedObject var vm: PracticeViewModel
    @StateObject private var recordVM = RecordViewModel()
    @StateObject private var scrollState = PianoScrollState()
    @StateObject private var visualizer = PracticeVisualizerModel()

    var body: some View {
        VStack(spacing: 12) {
            PracticeNoteVisualizerGrid(model: visualizer)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 16)
                .layoutPriority(1)

            PianoWithScroller(
                vm: recordVM,
                scrollState: scrollState
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
