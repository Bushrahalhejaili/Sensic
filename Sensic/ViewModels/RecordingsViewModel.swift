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

    private(set) var hasLoaded = false

    var toastMessage: String? {
        get { store.toastMessage }
        set { store.toastMessage = newValue }
    }

    init(store: RecordingsStore = .shared) {
        self.store = store
    }

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        hasLoaded = true
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

    func deletePiece(id: UUID, albumsStore: AlbumsStore) {
        store.permanentlyDeleteRecording(id: id, albumsStore: albumsStore)
        if revealedRecordingID == id {
            revealedRecordingID = nil
        }
    }

    func clearToast() {
        store.clearToast()
    }
}



