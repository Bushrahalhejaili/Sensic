//
//  HomeView.swift
//  Sensic
//

import SwiftUI

struct HomeView: View {
    @State private var viewModel: HomeViewModel

    @MainActor
    init() {
        _viewModel = State(initialValue: HomeViewModel())
    }

    @MainActor
    init(viewModel: HomeViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ZStack {
            SensicColors.background
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 28) {
                    HomeHeaderView()

                    PianoInstrumentCard()

                    VStack(alignment: .leading, spacing: 14) {
                        RecordingsSectionHeader(showsSeeAll: viewModel.hasRecordings)

                        recordingsPanel
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
        }
        .preferredColorScheme(.dark)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
    }

    @ViewBuilder
    private var recordingsPanel: some View {
        VStack(spacing: 14) {
            if viewModel.showsRecordingActions {
                RecordingActionBar()
            }

            Group {
                if viewModel.hasRecordings {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 10) {
                            ForEach(viewModel.recordings) { piece in
                                RecordingRowView(
                                    piece: piece,
                                    isSelected: viewModel.selectedRecordingID == piece.id
                                )
                                .onTapGesture {
                                    viewModel.selectedRecordingID = piece.id
                                }
                            }
                        }
                    }
                } else {
                    RecordingsEmptyState()
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: RecordingsPanelMetrics.contentHeight)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(SensicColors.panelNavy)
        )
    }
}

#Preview("Empty") {
    HomeView()
}

#Preview("List") {
    HomeView(viewModel: .previewWithList)
}

#Preview("With actions") {
    HomeView(viewModel: .previewWithActions)
}
