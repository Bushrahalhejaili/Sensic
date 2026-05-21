//
//  AlbumsViewModel.swift
//  Sensic
//

import Foundation
import Observation

@Observable
@MainActor
final class AlbumsViewModel {

    var albums: [Album] = []

    var showCreateAlbum = false

    var albumName = ""

    func createAlbum() {

        let trimmed =
        albumName.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !trimmed.isEmpty else {
            return
        }

        let newAlbum = Album(
            id: UUID(),
            name: trimmed,
            pieceIDs: []
        )

        albums.append(newAlbum)

        albumName = ""

        showCreateAlbum = false
    }

    func updateAlbumName(id: UUID, newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if let index = albums.firstIndex(where: { $0.id == id }) {
            albums[index].name = trimmed
        }
    }
}

