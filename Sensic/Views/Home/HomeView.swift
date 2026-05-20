//
//  HomeView.swift
//  Sensic
//

import SwiftUI

private enum HomeDestination: Hashable {
    case creation
    case recordings
}

struct HomeView: View {
    @Bindable private var store: RecordingsStore
    @State private var viewModel: HomeViewModel
    @State private var recordingsViewModel: RecordingsViewModel
    @State private var navigationPath = NavigationPath()

    @MainActor
    init(store: RecordingsStore = .shared) {
        _store = Bindable(wrappedValue: store)
        _viewModel = State(initialValue: HomeViewModel(store: store))
        _recordingsViewModel = State(initialValue: RecordingsViewModel(store: store))
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                SensicColors.background
                    .ignoresSafeArea()

                VStack(alignment: .leading, spacing: 28) {
                    HomeHeaderView()
                        .fixedSize(horizontal: false, vertical: true)

                    PianoInstrumentCard(openCreation: openCreation)
                        .fixedSize(horizontal: false, vertical: true)
                        //.frame(height: 300)
                    VStack(alignment: .leading, spacing: 14) {
                        RecordingsSectionHeader(
                            showsSeeAll: viewModel.hasRecordings,
                            onSeeAll: openRecordings
                        )

                        recordingsPanel
                    }
                    .layoutPriority(-1)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                if let message = store.toastMessage {
                    VStack {
                        RecordingsToastView(message: message)
                            .padding(.top, 8)
                        Spacer()
                    }
                    .onAppear {
                        Task {
                            try? await Task.sleep(for: .seconds(2))
                            store.clearToast()
                        }
                    }
                }
            }
            .preferredColorScheme(.dark)
            .toolbar(.hidden, for: .navigationBar)
            .toolbar(.hidden, for: .tabBar)
            .navigationDestination(for: HomeDestination.self) { destination in
                switch destination {
                case .creation:
                    CreationView(store: store, onSavedToRecordings: openRecordingsAfterSave)
                case .recordings:
                    RecordingsView(store: store, viewModel: recordingsViewModel)
                }
            }
            .sheet(item: $viewModel.piecePendingRename) { piece in
                RenameRecordingSheet(piece: piece, viewModel: recordingsViewModel)
            }
            .alert(
                "Delete recording?",
                isPresented: Binding(
                    get: { viewModel.piecePendingDelete != nil },
                    set: { if !$0 { viewModel.piecePendingDelete = nil } }
                ),
                presenting: viewModel.piecePendingDelete
            ) { piece in
                Button("Delete", role: .destructive) {
                    viewModel.deletePiece(id: piece.id)
                    viewModel.piecePendingDelete = nil
                }
                Button("Cancel", role: .cancel) {
                    viewModel.piecePendingDelete = nil
                }
            } message: { piece in
                Text("“\(piece.title)” will be removed from your library.")
            }
            .task {
                await viewModel.load()
            }
        }
    }

    private func openCreation() {
        navigationPath.append(HomeDestination.creation)
    }

    private func openRecordings() {
        navigationPath.append(HomeDestination.recordings)
    }

    private func openRecordingsAfterSave() {
        if navigationPath.count > 0 {
            navigationPath.removeLast()
        }
        navigationPath.append(HomeDestination.recordings)
    }

    @ViewBuilder
    private var recordingsPanel: some View {
        VStack(spacing: 0) {
            if viewModel.hasRecordings {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 10) {
                        ForEach(viewModel.recentRecordings) { piece in
                            SwipeableRecordingRow(
                                piece: piece,
                                revealedRecordingID: $viewModel.revealedRecordingID,
                                onRename: { viewModel.piecePendingRename = piece },
                                onAdd: { viewModel.showAlbumsComingSoon() },
                                onDelete: { viewModel.piecePendingDelete = piece }
                            )
                        }
                    }
                    .padding(16)
                }
            } else {
                RecordingsEmptyState()
                    .padding(16)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: RecordingsPanelMetrics.contentHeight)
        .background(
            RoundedRectangle(cornerRadius: RecordingsPanelMetrics.cornerRadius, style: .continuous)
                .fill(SensicColors.recordingsPanelBackground)
        )
        .clipShape(RoundedRectangle(cornerRadius: RecordingsPanelMetrics.cornerRadius, style: .continuous))
    }
}

#Preview("Empty") {
    HomeView(store: RecordingsStore())
}

#Preview("List") {
    HomeView(store: .previewInstance())
}
