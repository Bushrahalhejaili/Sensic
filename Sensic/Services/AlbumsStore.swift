//
//  AlbumsStore.swift
//  Sensic
//

import Foundation
import Observation

@Observable
@MainActor
final class AlbumsStore {
    static let shared = AlbumsStore()

    private(set) var albums: [Album] = []

    /// When true, `AlbumsView` opens the create-album sheet on appear (Home Add with no albums).
    var shouldPresentCreateOnAlbumsAppear = false

    private let albumsKey = "sensic.albums"

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    var hasAlbums: Bool { !albums.isEmpty }

    /// Newest album first (left in grid, top of list).
    var albumsNewestFirst: [Album] {
        albums.sorted { $0.createdAt > $1.createdAt }
    }

    init() {}

    static func previewInstance() -> AlbumsStore {
        let store = AlbumsStore()
        let now = Date()
        store.albums = [
            Album(name: "The great divide", createdAt: now.addingTimeInterval(-120)),
            Album(name: "Happy Tones", createdAt: now.addingTimeInterval(-60)),
            Album(name: "Girl's Girl", createdAt: now),
        ]
        return store
    }

    func loadIfNeeded() async {
        guard albums.isEmpty else { return }
        if let stored = loadAlbums() {
            albums = stored.enumerated().map { index, snapshot in
                legacyAlbum(from: snapshot, index: index, total: stored.count)
            }
        }
    }

    /// Older saves had no `createdAt`; preserve append order (last item = newest).
    private func legacyAlbum(from snapshot: StoredAlbum, index: Int, total: Int) -> Album {
        let createdAt = snapshot.createdAt ?? Date(
            timeIntervalSinceNow: -Double(max(0, total - 1 - index)) * 60
        )
        return Album(
            id: snapshot.id,
            name: snapshot.name,
            pieceIDs: snapshot.pieceIDs,
            createdAt: createdAt
        )
    }

    /// Drops piece IDs that no longer exist in the recordings library.
    func syncWithLibrary(validPieceIDs: Set<UUID>) {
        var didChange = false
        for album in albums {
            let before = album.pieceIDs.count
            album.pieceIDs.removeAll { !validPieceIDs.contains($0) }
            if album.pieceIDs.count != before { didChange = true }
        }
        if didChange { persist() }
    }

    @discardableResult
    func createAlbum(name: String) -> Album? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let album = Album(name: trimmed, createdAt: Date())
        albums.insert(album, at: 0)
        persist()
        return album
    }

    func setAlbumMembership(pieceID: UUID, albumIDs: Set<UUID>) {
        for index in albums.indices {
            if albumIDs.contains(albums[index].id) {
                if !albums[index].pieceIDs.contains(pieceID) {
                    albums[index].pieceIDs.append(pieceID)
                }
            } else {
                albums[index].pieceIDs.removeAll { $0 == pieceID }
            }
        }
        persist()
    }

    func albumIDs(containingPieceID pieceID: UUID) -> Set<UUID> {
        Set(
            albums
                .filter { $0.pieceIDs.contains(pieceID) }
                .map(\.id)
        )
    }

    /// Newest album that contains this piece (shown on recording rows).
    func firstAlbumName(forPieceID pieceID: UUID) -> String? {
        albums
            .filter { $0.pieceIDs.contains(pieceID) }
            .max(by: { $0.createdAt < $1.createdAt })?
            .name
    }

    func updateAlbumName(id: UUID, newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let album = albums.first(where: { $0.id == id }) else { return }
        album.name = trimmed
        persist()
    }

    func addRecordingIDs(_ ids: [UUID], toAlbumID albumID: UUID) {
        guard let index = albums.firstIndex(where: { $0.id == albumID }) else { return }
        let existing = Set(albums[index].pieceIDs)
        let unique = ids.filter { !existing.contains($0) }
        albums[index].pieceIDs.append(contentsOf: unique)
        persist()
    }

    func removePiece(id: UUID, fromAlbumID albumID: UUID) {
        guard let index = albums.firstIndex(where: { $0.id == albumID }) else { return }
        albums[index].pieceIDs.removeAll { $0 == id }
        persist()
    }

    /// Call when a recording is deleted from the library so albums don't keep stale IDs.
    func removePieceFromAllAlbums(_ pieceID: UUID) {
        var didChange = false
        for album in albums where album.pieceIDs.contains(pieceID) {
            album.pieceIDs.removeAll { $0 == pieceID }
            didChange = true
        }
        if didChange { persist() }
    }

    func movePiece(id: UUID, fromAlbumID sourceID: UUID, toAlbumID destinationID: UUID) {
        guard sourceID != destinationID else { return }
        guard let sourceIndex = albums.firstIndex(where: { $0.id == sourceID }) else { return }
        guard let destinationIndex = albums.firstIndex(where: { $0.id == destinationID }) else { return }

        albums[sourceIndex].pieceIDs.removeAll { $0 == id }
        if !albums[destinationIndex].pieceIDs.contains(id) {
            albums[destinationIndex].pieceIDs.append(id)
        }
        persist()
    }

    // MARK: - Persistence

    @discardableResult
    func persist() -> Bool {
        let snapshots = albums.map(StoredAlbum.init(album:))
        guard let data = try? encoder.encode(snapshots) else { return false }
        UserDefaults.standard.set(data, forKey: albumsKey)
        return true
    }

    private func loadAlbums() -> [StoredAlbum]? {
        guard let data = UserDefaults.standard.data(forKey: albumsKey) else { return nil }
        return try? decoder.decode([StoredAlbum].self, from: data)
    }
}
