//
//  AlbumsViewModel.swift
//  Sensic
//
import Foundation
import Observation

@Observable
@MainActor
final class AlbumsViewModel {

    private let albumsStore: AlbumsStore
    private let recordingsStore: RecordingsStore

    // MARK: - Data

    var albums: [Album] { albumsStore.albums }

    // MARK: - UI State

    var showCreateAlbum = false
    var albumName = ""

    init(
        albumsStore: AlbumsStore = .shared,
        recordingsStore: RecordingsStore = .shared
    ) {
        self.albumsStore = albumsStore
        self.recordingsStore = recordingsStore
    }

    // MARK: - Create Album

    func createAlbum() {
        guard albumsStore.createAlbum(name: albumName) != nil else { return }
        albumName = ""
        showCreateAlbum = false
    }

    // MARK: - Update Name

    func updateAlbumName(id: UUID, newName: String) {
        albumsStore.updateAlbumName(id: id, newName: newName)
    }

    // MARK: - Add Recordings

    func addRecordings(_ recordings: [RecordingItem], to album: Album) {
        albumsStore.addRecordingIDs(recordings.map(\.id), toAlbumID: album.id)
    }

    /// Library pieces that belong to this album (same IDs as Home / Recordings).
    func recordings(for album: Album) -> [RecordingItem] {
        recordingsStore.pieces
            .filter { album.pieceIDs.contains($0.id) }
            .map(RecordingItem.init(piece:))
    }

    /// All saved pieces offered when picking recordings inside an album.
    func allRecordingsForPicker() -> [RecordingItem] {
        recordingsStore.pieces.map(RecordingItem.init(piece:))
    }

    // MARK: - Recording actions (album context)

    func renameRecording(id: UUID, title: String) -> Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        recordingsStore.renamePiece(id: id, title: trimmed)
        return true
    }

    func removeRecording(id: UUID, fromAlbumID albumID: UUID) {
        albumsStore.removePiece(id: id, fromAlbumID: albumID)
    }

    func moveRecording(id: UUID, fromAlbumID sourceID: UUID, toAlbumID destinationID: UUID) {
        albumsStore.movePiece(id: id, fromAlbumID: sourceID, toAlbumID: destinationID)
    }
}
