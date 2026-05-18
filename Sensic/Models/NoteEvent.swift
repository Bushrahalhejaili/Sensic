//
//  NoteEvent.swift
//  Sensic
//
//  Created by شهد عبدالله القحطاني on 29/11/1447 AH.
//


// PracticeSession.swift
// Sensic

import Foundation

struct NoteEvent: Codable {
    var midiNote:  UInt8
    var velocity:  UInt8
    var timestamp: TimeInterval   // ثواني من بداية السشن
    var duration:  TimeInterval   // كم ثانية ضغط المفتاح
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

struct PianoKeyModel: Identifiable {
    let id      = UUID()
    let midi:     UInt8
    let isBlack:  Bool
    let noteName: String
    let octave:   Int
}
