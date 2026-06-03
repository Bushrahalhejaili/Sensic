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
///
/// Codable so a `TrackSnapshot` (and therefore a saved `Piece`) can
/// be persisted with its full per-track note list intact.  The
/// `id` field is intentionally NOT encoded — a fresh UUID is
/// generated on decode, since identity is only meaningful within
/// the lifetime of a single editing session.
struct RecordedNote: Identifiable, Equatable, Codable {
    let id: UUID
    /// `var` (not `let`) so the edit sheet's piano-roll drag can
    /// move a note to a different lane without having to replace
    /// the whole record — handy because the `id` should survive a
    /// pitch change for selection / undo bookkeeping.
    var midi: UInt8
    var startSeconds: TimeInterval
    var endSeconds: TimeInterval?
    let velocity: UInt8

    init(midi: UInt8,
         startSeconds: TimeInterval,
         endSeconds: TimeInterval? = nil,
         velocity: UInt8) {
        self.id = UUID()
        self.midi = midi
        self.startSeconds = startSeconds
        self.endSeconds = endSeconds
        self.velocity = velocity
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case midi, startSeconds, endSeconds, velocity
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        self.midi         = try c.decode(UInt8.self,        forKey: .midi)
        self.startSeconds = try c.decode(TimeInterval.self, forKey: .startSeconds)
        self.endSeconds   = try c.decodeIfPresent(TimeInterval.self,
                                                  forKey: .endSeconds)
        self.velocity     = try c.decode(UInt8.self,        forKey: .velocity)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(midi,         forKey: .midi)
        try c.encode(startSeconds, forKey: .startSeconds)
        try c.encodeIfPresent(endSeconds, forKey: .endSeconds)
        try c.encode(velocity,     forKey: .velocity)
    }
}
