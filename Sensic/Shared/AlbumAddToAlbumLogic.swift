//
//  AlbumAddToAlbumLogic.swift
//  Sensic
//

import Foundation

@MainActor
enum AlbumAddToAlbumLogic {
    static func finish(
        piece: Piece,
        albumIDs: Set<UUID>,
        albumsStore: AlbumsStore,
        recordingsStore: RecordingsStore
    ) {
        let before = albumsStore.albumIDs(containingPieceID: piece.id)

        albumsStore.setAlbumMembership(pieceID: piece.id, albumIDs: albumIDs)

        let added = albumIDs.subtracting(before)
        let removed = before.subtracting(albumIDs)

        if !added.isEmpty, added.count == 1,
           let name = albumsStore.albums.first(where: { added.contains($0.id) })?.name {
            recordingsStore.showToast("Added to \"\(name)\"")
        } else if !added.isEmpty {
            recordingsStore.showToast("Added to \(added.count) albums")
        } else if !removed.isEmpty {
            recordingsStore.showToast("Removed from albums")
        }
    }
}
