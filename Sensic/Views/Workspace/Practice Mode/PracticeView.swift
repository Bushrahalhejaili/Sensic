//
//  PracticeView.swift
//  Sensic
//

import SwiftUI
import Combine

// MARK: - Visualizer Card

private struct VisualizerCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        ZStack {
            content.padding(10)
        }
        .background(Color(red: 0.043, green: 0.075, blue: 0.169))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .glassEffect(in: .rect(cornerRadius: 28))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(
                    LinearGradient(
                        stops: [
                            .init(color: Color.white.opacity(0.55), location: 0.0),
                            .init(color: Color.white.opacity(0.20), location: 0.3),
                            .init(color: Color.white.opacity(0.0),  location: 0.5),
                            .init(color: Color(red:0.043,green:0.075,blue:0.169).opacity(0.3), location: 0.7),
                            .init(color: Color(red:0.043,green:0.075,blue:0.169).opacity(0.55), location: 1.0)
                        ],
                        startPoint: .topTrailing,
                        endPoint: .bottomLeading
                    ),
                    lineWidth: 1.2
                )
        )
        .shadow(color: .black.opacity(0.45), radius: 24, y: 12)
    }
}

// MARK: - Visualizer Container

struct PracticeVisualizerContainer: View {
    @ObservedObject var model: PracticeVisualizerModel
    @State private var selectedStyle: Int = 0

    var body: some View {
        TabView(selection: $selectedStyle) {
            VisualizerCard { DotsGridVisualizer(model: model) }.tag(0)
            VisualizerCard { CircularDotsVisualizer(model: model) }.tag(1)
            VisualizerCard { WaveformVisualizer(model: model) }.tag(2)
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .never))
        .animation(.easeInOut(duration: 0.25), value: selectedStyle)
    }
}

// MARK: - PracticeView

struct PracticeView: View {
    @ObservedObject var vm: PracticeViewModel
    @ObservedObject private var recordVM       = AudioEngine.shared
    @StateObject private var scrollState       = PianoScrollState()
    @StateObject private var visualizer        = PracticeVisualizerModel()
    @ObservedObject private var hapticSettings = HapticSettings.shared

    var body: some View {
        VStack(spacing: 12) {

            PracticeVisualizerContainer(model: visualizer)
                .frame(maxWidth: .infinity)
                .frame(height: 240)
                .padding(.horizontal, 20)

            HapticSettingsCard(settings: hapticSettings)
                .padding(.horizontal, 20)

            Spacer(minLength: 0)

            PianoWithScroller(vm: recordVM, scrollState: scrollState)
                .frame(height: CreationLayout.pianoBlockHeight)
        }
        .padding(.top, 8)
        .onAppear { refreshVisualizer() }
        .onReceive(Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()) { _ in
            refreshVisualizer()
        }
        .onChange(of: recordVM.activeNotes)      { _, _ in refreshVisualizer() }
        .onChange(of: scrollState.offset)        { _, _ in refreshVisualizer() }
        .onChange(of: scrollState.viewportWidth) { _, _ in refreshVisualizer() }
    }

    private func refreshVisualizer() {
        visualizer.update(
            activeNotes: recordVM.activeNotes,
            scrollState: scrollState,
            velocities:  recordVM.activeNoteVelocities
        )
    }
}
