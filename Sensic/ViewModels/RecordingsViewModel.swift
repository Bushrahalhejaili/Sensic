//
//  RecordingsViewModel.swift
//  Sensic
//

import Foundation
import Observation

@Observable
@MainActor
final class RecordingsViewModel {
    private let store: RecordingsStore

    var searchText = ""
    var revealedRecordingID: UUID?
    var isLoading = false

    var piecePendingRename: Piece?
    var piecePendingDelete: Piece?

    var toastMessage: String? {
        get { store.toastMessage }
        set { store.toastMessage = newValue }
    }

    init(store: RecordingsStore = .shared) {
        self.store = store
    }

    func load() async {
        isLoading = true
        await store.loadIfNeeded()
        isLoading = false
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

    /// Albums are not implemented yet — placeholder for Add/Move actions.
    func showAlbumsComingSoon() {
        store.showToast("Albums coming soon")
    }

    func clearToast() {
        store.clearToast()
    }
}
