//
//  HomeView.swift
//  Sensic
//
//

import SwiftUI

private enum HomeDestination: Hashable {
    case creation
    case recordings
    case albums
}

struct HomeView: View {
    @Bindable private var store: RecordingsStore
    @Bindable private var albumsStore: AlbumsStore
    @State private var viewModel: HomeViewModel
    @State private var recordingsViewModel: RecordingsViewModel
    @State private var navigationPath = NavigationPath()
    @State private var pieceToAddToAlbum: Piece?

    @MainActor
    init(
        store: RecordingsStore = .shared,
        albumsStore: AlbumsStore = .shared
    ) {
        _store = Bindable(wrappedValue: store)
        _albumsStore = Bindable(wrappedValue: albumsStore)
        _viewModel = State(initialValue: HomeViewModel(store: store))
        _recordingsViewModel = State(initialValue: RecordingsViewModel(store: store))
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                Color.black
                    .ignoresSafeArea()

                VStack(alignment: .leading, spacing: HomeLayout.sectionSpacing) {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Spacer(minLength: 0)

                            HomeAlbumLibraryButton {
                                openAlbums()
                            }
                        }

                        HomeHeaderView()
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    PianoInstrumentCard(openCreation: openCreation)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(alignment: .leading, spacing: HomeLayout.subsectionSpacing) {
                        RecordingsSectionHeader(
                            showsSeeAll: viewModel.hasRecordings,
                            onSeeAll: openRecordings
                        )

                        recordingsPanel
                    }
                    .layoutPriority(-1)
                }
                .padding(.horizontal, HomeLayout.horizontalPadding)
                .padding(.top, 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                if let message = store.toastMessage {
                    VStack {
                        RecordingsToastView(message: message)
                            .padding(.top, 8)

                        Spacer()
                    }
                    .task(id: message) {
                        try? await Task.sleep(for: .seconds(2))
                        store.clearToast()
                    }
                }
            }
            .preferredColorScheme(.dark)
            .toolbar(.hidden, for: .navigationBar)
            .toolbar(.hidden, for: .tabBar)

            .navigationDestination(for: HomeDestination.self) { destination in
                switch destination {

                case .creation:
                    CreationView(
                        store: store,
                        onSavedToRecordings: openRecordingsAfterSave
                    )

                case .recordings:
                    RecordingsView(
                        store: store,
                        albumsStore: albumsStore,
                        viewModel: recordingsViewModel
                    )

                case .albums:
                    AlbumsView(albumsStore: albumsStore, recordingsStore: store)
                }
            }

            .sheet(item: $viewModel.piecePendingRename) { piece in
                RenameRecordingSheet(
                    piece: piece,
                    viewModel: recordingsViewModel
                )
            }

            .alert(
                "Delete recording?",
                isPresented: Binding(
                    get: { viewModel.piecePendingDelete != nil },
                    set: {
                        if !$0 {
                            viewModel.piecePendingDelete = nil
                        }
                    }
                ),
                presenting: viewModel.piecePendingDelete
            ) { piece in

                Button("Delete", role: .destructive) {
                    viewModel.deletePiece(id: piece.id, albumsStore: albumsStore)
                    viewModel.piecePendingDelete = nil
                }

                Button("Cancel", role: .cancel) {
                    viewModel.piecePendingDelete = nil
                }

            } message: { piece in

                Text("“\(piece.title)” will be removed from your library.")
            }

            .task {
                await viewModel.performInitialLoad(albumsStore: albumsStore)
            }

            .sheet(item: $pieceToAddToAlbum) { piece in
                AddToAlbumPickerView(
                    piece: piece,
                    albumsStore: albumsStore,
                    recordingsStore: store,
                    onFinished: { pieceToAddToAlbum = nil },
                    onCancel: { pieceToAddToAlbum = nil }
                )
            }
        }
    }

    private func openCreation() {
        navigationPath.append(HomeDestination.creation)
    }

    private func openRecordings() {
        navigationPath.append(HomeDestination.recordings)
    }

    private func openAlbums() {
        navigationPath.append(HomeDestination.albums)
    }

    private func handleAddToAlbum(_ piece: Piece) {
        viewModel.revealedRecordingID = nil

        guard albumsStore.hasAlbums else {
            albumsStore.shouldPresentCreateOnAlbumsAppear = true
            openAlbums()
            return
        }

        albumsStore.syncWithLibrary(validPieceIDs: Set(store.pieces.map(\.id)))
        pieceToAddToAlbum = piece
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

                    VStack(spacing: RecordingsPanelMetrics.rowSpacing) {

                        ForEach(viewModel.recentRecordings) { piece in

                            SwipeableRecordingRow(
                                piece: piece,
                                primaryAlbumName: albumsStore.firstAlbumName(forPieceID: piece.id),
                                revealedRecordingID: $viewModel.revealedRecordingID,
                                onRename: {
                                    viewModel.piecePendingRename = piece
                                },
                                onAdd: {
                                    handleAddToAlbum(piece)
                                },
                                onDelete: {
                                    viewModel.piecePendingDelete = piece
                                }
                            )
                        }
                    }
                    .padding(RecordingsPanelMetrics.panelInset)
                }

            } else {

                RecordingsEmptyState()
                    .padding(RecordingsPanelMetrics.panelInset)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(
            height: RecordingsPanelMetrics.panelHeight(
                rowCount: viewModel.recentRecordings.count,
                isEmpty: !viewModel.hasRecordings
            )
        )
        .background(
            RoundedRectangle(
                cornerRadius: RecordingsPanelMetrics.cornerRadius,
                style: .continuous
            )
            .fill(Color("SpaceBlue").opacity(0.5))
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: RecordingsPanelMetrics.cornerRadius,
                style: .continuous
            )
        )
    }
}

#Preview("Empty") {
    HomeView(store: RecordingsStore())
}

#Preview("List") {
    HomeView(store: .previewInstance())
}


