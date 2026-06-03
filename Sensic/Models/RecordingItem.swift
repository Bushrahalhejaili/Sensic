//
//  RecordingItem.swift
//  Sensic
//

import Foundation

struct RecordingItem: Identifiable, Equatable {
    let id: UUID
    var title: String
    let duration: String
    let date: String

    init(
        id: UUID = UUID(),
        title: String,
        duration: String,
        date: String
    ) {
        self.id = id
        self.title = title
        self.duration = duration
        self.date = date
    }

    init(piece: Piece) {
        self.init(
            id: piece.id,
            title: piece.title,
            duration: piece.formattedDuration,
            date: piece.listDateLabel()
        )
    }
}


