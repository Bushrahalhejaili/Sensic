//
//  Album.swift
//  Sensic
//

import Foundation
import Observation

@Observable
final class Album: Identifiable {

    let id: UUID
    let createdAt: Date
    var name: String
    var pieceIDs: [UUID]

    init(id: UUID = UUID(), name: String, pieceIDs: [UUID] = [], createdAt: Date = Date()) {
        self.id = id
        self.createdAt = createdAt
        self.name = name
        self.pieceIDs = pieceIDs
    }
}

/// Plain snapshot for UserDefaults — avoids encoding `@Observable` classes.
struct StoredAlbum: Codable, Identifiable {
    let id: UUID
    let createdAt: Date?
    var name: String
    var pieceIDs: [UUID]

    init(id: UUID, name: String, pieceIDs: [UUID], createdAt: Date) {
        self.id = id
        self.createdAt = createdAt
        self.name = name
        self.pieceIDs = pieceIDs
    }

    init(album: Album) {
        id = album.id
        createdAt = album.createdAt
        name = album.name
        pieceIDs = album.pieceIDs
    }

    func makeAlbum() -> Album {
        Album(id: id, name: name, pieceIDs: pieceIDs, createdAt: createdAt ?? Date.distantPast)
    }
}
