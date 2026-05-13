//
//  Album.swift
//  Sensic
//

import Foundation

struct Album: Identifiable, Equatable {
    let id: UUID
    var name: String
    var pieceIDs: [UUID]
}
