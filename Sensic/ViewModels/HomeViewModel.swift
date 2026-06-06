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

    /// Home panel only: last 4 by date (newest first), restricted
    /// to pieces created within the last 7 calendar days.  Older
    /// recordings disappear from the home page after a week but
    /// remain available on the Recordings screen indefinitely.
    private let homeRecordingsPreviewLimit = 4

    var recentRecordings: [Piece] {
        Self.recentRecordings(from: store.pieces, limit: homeRecordingsPreviewLimit)
    }

    static func recentRecordings(from pieces: [Piece], limit: Int = 4) -> [Piece] {
        let calendar = Calendar.current
        let now = Date()
        let inLastSevenDays = pieces.filter { piece in
            let days = calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: piece.createdAt),
                to:   calendar.startOfDay(for: now)
            ).day ?? 0
            return days < 7
        }
        return Array(
            inLastSevenDays
                .sorted { $0.createdAt > $1.createdAt }
                .prefix(limit)
        )
    }

    /// True when there's at least one piece eligible for the home
    /// panel right now.  Distinct from `hasRecordings`, which stays
    /// true as long as ANY pieces exist (used for the "See All"
    /// button — older recordings still live on Recordings even when
    /// the home panel is empty).
    var hasRecentRecordings: Bool { !recentRecordings.isEmpty }

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
        store.permanentlyDeleteRecording(id: id, albumsStore: albumsStore)
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
