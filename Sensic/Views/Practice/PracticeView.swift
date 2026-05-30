//
//  PracticeView.swift
//  Sensic
//

import SwiftUI
import Combine
import CoreHaptics

// MARK: - Haptic Settings Model

class HapticSettings: ObservableObject {
    @Published var intensity: Double = 0.5
    @Published var sharpness: Double = 0.5
    @Published var style: HapticStyle = .smooth

    enum HapticStyle { case smooth, punchy }
}

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

// MARK: - Haptic Settings Card

private struct HapticSettingsCard: View {
    @ObservedObject var settings: HapticSettings

    var body: some View {
        HStack(spacing: 0) {

            // يسار — sliders
            VStack(alignment: .leading, spacing: 18) {
                hapticSlider(label: "Haptic Intensity", value: $settings.intensity)
                hapticSlider(label: "Haptic Sharpness", value: $settings.sharpness)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity)

            // divider عمودي
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(width: 1)
                .padding(.vertical, 14)

            // يمين — style buttons
            VStack(alignment: .center, spacing: 10) {
                Text("Haptic style")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .center)

                styleButton("Smooth", style: .smooth)
                styleButton("Punchy", style: .punchy)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 18)
            .frame(width: 130)
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

    private func hapticSlider(label: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)

            // Slider مخصص مع toggle يتحرك
            Slider(value: value)
                .tint(Color("MainPurple"))
        }
    }

    private func styleButton(_ title: String, style: HapticSettings.HapticStyle) -> some View {
        let selected = settings.style == style
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                settings.style = style
            }
        } label: {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    selected
                        ? Color("MainPurple")
                        : Color(red: 0.043, green: 0.075, blue: 0.169)
                )
                .clipShape(Capsule())
                .glassEffect(in: .capsule)
                .overlay(
                    Capsule()
                        .stroke(
                            LinearGradient(
                                stops: [
                                    .init(color: Color.white.opacity(0.0),  location: 0.0),
                                    .init(color: Color.white.opacity(0.70), location: 0.5),
                                    .init(color: Color.white.opacity(0.0),  location: 1.0)
                                ],
                                startPoint: .topTrailing,
                                endPoint: .bottomLeading
                            ),
                            lineWidth: 1.5
                        )
                )
                .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
    }
}



// MARK: - PracticeView

struct PracticeView: View {
    @ObservedObject var vm: PracticeViewModel
    @StateObject private var recordVM       = RecordViewModel()
    @StateObject private var scrollState    = PianoScrollState()
    @StateObject private var visualizer     = PracticeVisualizerModel()
    @StateObject private var hapticSettings = HapticSettings()

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
