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

    func load() async {
        await store.loadIfNeeded()
    }

    func renamePiece(id: UUID, title: String) -> Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        store.renamePiece(id: id, title: trimmed)
        return true
    }

    func deletePiece(id: UUID) {
        store.deletePiece(id: id)
        if revealedRecordingID == id {
            revealedRecordingID = nil
        }
    }

    func showAlbumsComingSoon() {
        store.showToast("Albums coming soon")
    }
}


