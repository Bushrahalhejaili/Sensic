//
//  HomeViewModel.swift
//  Sensic
//

import Foundation
import Observation

@Observable
@MainActor
final class HomeViewModel {
    private let store: RecordingsStore

    var revealedRecordingID: UUID?
    var showRecordingsPage = false

    var piecePendingRename: Piece?
    var piecePendingDelete: Piece?

    private(set) var hasPerformedInitialLoad = false

    var recordings: [Piece] { store.pieces }
    var hasRecordings: Bool { !store.pieces.isEmpty }

    /// Home panel only: last 4 by date (newest first). Full list lives on the Recordings screen.
    private let homeRecordingsPreviewLimit = 4

    var recentRecordings: [Piece] {
        let sorted = store.pieces.sorted { $0.createdAt > $1.createdAt }
        return Array(sorted.prefix(homeRecordingsPreviewLimit))
    }

    init(store: RecordingsStore = .shared) {
        self.store = store
    }

    /// Runs once per app session — avoids re-fetch when the home screen refreshes after Add.
    func performInitialLoad(albumsStore: AlbumsStore) async {
        guard !hasPerformedInitialLoad else { return }
        hasPerformedInitialLoad = true
        await store.loadIfNeeded()
        await albumsStore.loadIfNeeded()
        albumsStore.syncWithLibrary(validPieceIDs: Set(store.pieces.map(\.id)))
    }

    func renamePiece(id: UUID, title: String) -> Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        store.renamePiece(id: id, title: trimmed)
        return true
    }

    func deletePiece(id: UUID, albumsStore: AlbumsStore) {
        store.deletePiece(id: id)
        albumsStore.removePieceFromAllAlbums(id)
        if revealedRecordingID == id {
            revealedRecordingID = nil
        }
    }

    func finishAddToAlbum(
        piece: Piece,
        albumIDs: Set<UUID>,
        albumsStore: AlbumsStore
    ) {
        AlbumAddToAlbumLogic.finish(
            piece: piece,
            albumIDs: albumIDs,
            albumsStore: albumsStore,
            recordingsStore: store
        )
    }
}


