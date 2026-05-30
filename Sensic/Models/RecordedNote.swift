//
//  RecordedNote.swift
//  Sensic
//
//  Created by Bushra Hatim Alhejaili on 30/05/2026.
//


import Foundation

// MARK: - RecordedNote

/// A single recorded note with start and (optional, while still
/// held) end times measured in seconds from the start of the track.
struct RecordedNote: Identifiable, Equatable {
    let id = UUID()
    /// `var` (not `let`) so the edit sheet's piano-roll drag can
    /// move a note to a different lane without having to replace
    /// the whole record — handy because the `id` should survive a
    /// pitch change for selection / undo bookkeeping.
    var midi: UInt8
    var startSeconds: TimeInterval
    var endSeconds: TimeInterval?
    let velocity: UInt8
}
