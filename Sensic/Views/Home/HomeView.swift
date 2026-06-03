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
    /// Reopen an existing recording in CreationView with all its
    /// tracks restored.  The piece is identified by its `id` so we
    /// don't have to make `Piece` itself `Hashable`; the destination
    /// view resolves the actual `Piece` out of the store at render
    /// time, which also means an in-place edit immediately reflects
    /// without re-navigating.
    case editPiece(UUID)
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
                        viewModel: recordingsViewModel,
                        onOpenPiece: openPieceFromRecordings
                    )

                case .albums:
                    AlbumsView(albumsStore: albumsStore, recordingsStore: store)

                case .editPiece(let id):
                    if let piece = store.pieces.first(where: { $0.id == id }) {
                        CreationView(
                            store: store,
                            loadingPiece: piece
                        )
                    } else {
                        // Piece was deleted in another flow.  Drop
                        // back to Home rather than show an empty
                        // editor.
                        EmptyView()
                    }
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

    /// Push the editor for a piece tapped on Home — appends the
    /// editPiece destination onto the nav path so a back-tap
    /// returns to Home.
    private func openPiece(_ piece: Piece) {
        viewModel.revealedRecordingID = nil
        navigationPath.append(HomeDestination.editPiece(piece.id))
    }

    /// Pop RecordingsView off the nav stack and push the editor.
    /// Mirrors `openRecordingsAfterSave` but in the other direction
    /// — used as the `onOpenPiece` callback for `RecordingsView`'s
    /// row taps so a tap there also lands the user in CreationView.
    private func openPieceFromRecordings(_ piece: Piece) {
        if navigationPath.count > 0 {
            navigationPath.removeLast()
        }
        navigationPath.append(HomeDestination.editPiece(piece.id))
    }

    @ViewBuilder
    private var recordingsPanel: some View {

        VStack(spacing: 0) {

            if viewModel.hasRecentRecordings {

                ScrollView(showsIndicators: false) {

                    VStack(spacing: RecordingsPanelMetrics.rowSpacing) {

                        ForEach(viewModel.recentRecordings) { piece in

                            SwipeableRecordingRow(
                                piece: piece,
                                primaryAlbumName: albumsStore.firstAlbumName(forPieceID: piece.id),
                                revealedRecordingID: $viewModel.revealedRecordingID,
                                onOpen: {
                                    openPiece(piece)
                                },
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
                isEmpty: !viewModel.hasRecentRecordings
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
