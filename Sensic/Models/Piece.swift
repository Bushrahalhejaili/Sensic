//
//  Piece.swift
//  Sensic
//

import Foundation

struct Piece: Identifiable, Equatable {
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
        let calendar = Calendar.current
        if calendar.isDateInToday(createdAt) {
            return createdAt.formatted(date: .omitted, time: .shortened)
        }
        if calendar.isDateInYesterday(createdAt) {
            return "Yesterday"
        }
        return createdAt.formatted(.dateTime.month(.abbreviated).day())
    }
}
