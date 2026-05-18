// PracticeView.swift
// Sensic

import SwiftUI

struct PracticeView: View {
    @ObservedObject var vm: PracticeViewModel
    @StateObject private var recordVM = RecordViewModel()
    @State private var hapticIntensity: Float = 0.7
    @State private var hapticSharpness: Float = 0.5
    @State private var hapticStyle: HapticStyle = .smooth

    var body: some View {
        VStack(spacing: 12) {
            // Stats
            HStack(spacing: 10) {
                StatCard(label: "Sessions", value: "\(vm.sessions.count)")
                StatCard(label: "Notes",    value: "\(vm.totalNotes)")
                StatCard(label: "Accuracy", value: "\(vm.avgAccuracy)%")
            }
            .padding(.horizontal, 16)

            // Sessions list
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(vm.sessions) { session in
                        SessionRow(session: session) {
                            vm.deleteSession(id: session.id)
                        }
                    }
                    if vm.sessions.isEmpty {
                        Text("No sessions yet — tap + to start")
                            .font(.subheadline)
                            .foregroundStyle(SensicColors.secondaryText)
                            .padding(.top, 40)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }

            Spacer(minLength: 0)

            // البيانو
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
