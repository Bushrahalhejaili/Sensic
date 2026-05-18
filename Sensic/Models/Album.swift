//
//  Album.swift
//  Sensic
//

import Foundation

struct Album: Identifiable, Equatable, Codable {
    let id: UUID
    var name: String
    var pieceIDs: [UUID]
}
