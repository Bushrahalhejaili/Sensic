//
//  NoteEvent.swift
//  Sensic
//
//  Created by Bushra Hatim Alhejaili on 26/05/2026.
//


import Foundation

struct NoteEvent: Codable, Equatable {
    var midiNote:  UInt8
    var velocity:  UInt8
    var timestamp: TimeInterval
    var duration:  TimeInterval
}

struct PracticeSession: Identifiable, Codable {
    var id:              UUID
    var title:           String
    var noteEvents:      [NoteEvent]
    var durationSeconds: TimeInterval
    var accuracy:        Double        // 0.0 – 1.0
    var createdAt:       Date

    init(title: String) {
        self.id              = UUID()
        self.title           = title
        self.noteEvents      = []
        self.durationSeconds = 0
        self.accuracy        = 0
        self.createdAt       = .now
    }
}


