//
//  Album.swift
//  Sensic
//

import Foundation
import Observation

@Observable
final class Album: Identifiable, Codable {

    let id: UUID
    var name: String
    var pieceIDs: [UUID]
    var pieces: [Piece] = []
    
    init(id: UUID = UUID(), name: String, pieceIDs: [UUID] = []) {
        self.id = id
        self.name = name
        self.pieceIDs = pieceIDs
        
    }
}
