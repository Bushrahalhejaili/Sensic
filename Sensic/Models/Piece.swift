//
//  Piece.swift
//  Sensic
//

import Foundation

struct Piece: Identifiable, Equatable, Codable {
    let id: UUID
    var title: String
    var createdAt: Date
    /// Length in seconds (for waveform row).
    var duration: TimeInterval
    /// Flat, time-ordered note list — kept for the waveform render
    /// and as a robust fallback when reopening a piece.
    var noteEvents: [NoteEvent]
    /// Per-track snapshots that preserve the project's multi-track
    /// structure (notes, duration, name, start position, row).
    /// Optional because legacy pieces saved before this field
    /// existed only carry the flat `noteEvents`; the loader falls
    /// back to a single-track restore in that case.  Element [0]
    /// is the primary track; any further elements are pasted /
    /// archived tracks in their original order.
    var trackSnapshots: [TrackSnapshot]?

    init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date = Date(),
        duration: TimeInterval,
        noteEvents: [NoteEvent] = [],
        trackSnapshots: [TrackSnapshot]? = nil
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.duration = duration
        self.noteEvents = noteEvents
        self.trackSnapshots = trackSnapshots
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        duration = try container.decode(TimeInterval.self, forKey: .duration)
        noteEvents = try container.decodeIfPresent([NoteEvent].self, forKey: .noteEvents) ?? []
        trackSnapshots = try container.decodeIfPresent([TrackSnapshot].self, forKey: .trackSnapshots)
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, createdAt, duration, noteEvents, trackSnapshots
    }

    var formattedDuration: String {
        let total = max(0, Int(duration.rounded()))
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var relativeTimestamp: String {
        listDateLabel()
    }

    /// Label for recordings list rows (time, Yesterday, weekday, or month/day).
    func listDateLabel(relativeTo reference: Date = Date()) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(createdAt) {
            return createdAt.formatted(date: .omitted, time: .shortened)
        }
        if calendar.isDateInYesterday(createdAt) {
            return "Yesterday"
        }
        let startCreated = calendar.startOfDay(for: createdAt)
        let startReference = calendar.startOfDay(for: reference)
        let days = calendar.dateComponents([.day], from: startCreated, to: startReference).day ?? 0
        if days < 7 {
            return createdAt.formatted(.dateTime.weekday(.wide))
        }
        return createdAt.formatted(.dateTime.month(.abbreviated).day())
    }

    /// Bar count scales with recording length (8…14).
    var waveformBarCount: Int {
        min(max(8, Int(duration / 18) + 6), 14)
    }

    /// Deterministic waveform shape per piece — stable for the same `id`.
    var waveformHeights: [CGFloat] {
        let bytes = withUnsafeBytes(of: id.uuid) { Array($0) }
        let count = waveformBarCount
        return (0..<count).map { index in
            let a = bytes[index % bytes.count]
            let b = bytes[(index + 7) % bytes.count]
            let mixed = (UInt16(a) + UInt16(b)) % 256
            return CGFloat(0.28 + Double(mixed) / 255.0 * 0.67)
        }
    }
}
