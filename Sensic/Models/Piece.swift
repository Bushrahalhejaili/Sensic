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
