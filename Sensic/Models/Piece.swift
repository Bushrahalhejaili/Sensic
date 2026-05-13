//
//  Piece.swift
//  Sensic
//

import Foundation

struct Piece: Identifiable, Equatable {
    let id: UUID
    var title: String
    var createdAt: Date
}
