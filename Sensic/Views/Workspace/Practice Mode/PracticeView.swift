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

    /// Piano scroll state is owned by `CreationView` so the piano
    /// in both modes shares one scroll position — switching tabs
    /// preserves wherever the user was looking.  The visualizer
    /// also reads from this to map active notes to screen space.
    @ObservedObject var scrollState: PianoScrollState

    @ObservedObject private var recordVM       = AudioEngine.shared
    @StateObject private var visualizer        = PracticeVisualizerModel()
    @ObservedObject private var hapticSettings = HapticSettings.shared

    var body: some View {
        VStack(spacing: 0) {

            // Top spacer mirrors `recordWorkspace`'s spacer — both
            // VStacks have one flexible region above their content,
            // so the first visible element below it (toolBar in
            // Record, visualizer card in Practice) ends up at the
            // same y-position.  Without this, the cards would
            // stick to the headerBar at the top and the chevron +
            // segment picker would appear to shift between modes.
            Spacer(minLength: 0)

            PracticeVisualizerContainer(model: visualizer)
                .frame(maxWidth: .infinity)
                .frame(height: 240)
                .padding(.horizontal, 20)
                // Mirrors toolBar's `.padding(.top, 20)` so the
                // visualizer's top edge aligns with where the
                // toolBar's top edge would be in Record mode.
                .padding(.top, 20)
                .padding(.bottom, 12)

            HapticSettingsCard(settings: hapticSettings)
                .padding(.horizontal, 20)
                // Provides the gap between haptic card and piano
                // scroller.  Mirrors toolBar's `.padding(.bottom,
                // 10)` in Record mode, where the same 10pt sits
                // between the toolBar's bottom edge and whatever
                // comes next (haptic card or timeline).
                .padding(.bottom, 10)

            // Piano placement note: Record mode adds `.padding(
            // .top, 30)` here to leave a 30pt gap between the
            // timeline's bottom and the piano scroller's top.
            // Practice mode has no timeline — those 30pt sit
            // between the haptic card and the piano scroller and
            // visually amount to wasted space.  Removing the top
            // padding releases 30pt of vertical space that the
            // top Spacer absorbs instead, sliding the cards down
            // to line up with where the toolBar sits in Record
            // mode.  The piano itself does NOT move: it's
            // anchored to the screen bottom by the VStack's
            // `.ignoresSafeArea(.container, edges: .bottom)`
            // combined with the fixed `.padding(.bottom, 9)`
            // below — both of those are unchanged.
            PianoWithScroller(vm: recordVM, scrollState: scrollState)
                .frame(height: CreationLayout.pianoBlockHeight)
                .padding(.bottom, 9)
        }
        .ignoresSafeArea(.container, edges: .bottom)
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
