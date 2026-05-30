//
//  RecordingSection.swift
//  Sensic
//

import Foundation

struct RecordingSection: Identifiable, Equatable {
    let id: String
    let title: String
    let pieces: [Piece]
}

enum RecordingSectionBuilder {
    static func sections(from pieces: [Piece], relativeTo reference: Date = Date()) -> [RecordingSection] {
        let sorted = pieces.sorted { $0.createdAt > $1.createdAt }
        let calendar = Calendar.current

        var today: [Piece] = []
        var previousSeven: [Piece] = []
        var byMonth: [Date: [Piece]] = [:]

        for piece in sorted {
            if calendar.isDateInToday(piece.createdAt) {
                today.append(piece)
                continue
            }

            let startCreated = calendar.startOfDay(for: piece.createdAt)
            let startReference = calendar.startOfDay(for: reference)
            let days = calendar.dateComponents([.day], from: startCreated, to: startReference).day ?? 0

            if days < 7 {
                previousSeven.append(piece)
                continue
            }

            let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: piece.createdAt)) ?? piece.createdAt
            byMonth[monthStart, default: []].append(piece)
        }

        var result: [RecordingSection] = []
        if !today.isEmpty {
            result.append(RecordingSection(id: "today", title: "Today", pieces: today))
        }
        if !previousSeven.isEmpty {
            result.append(RecordingSection(id: "previous7", title: "Previous 7 Day", pieces: previousSeven))
        }

        let monthKeys = byMonth.keys.sorted(by: >)
        for monthStart in monthKeys {
            guard let piecesInMonth = byMonth[monthStart] else { continue }
            let title = monthStart.formatted(.dateTime.month(.wide))
            let id = monthStart.formatted(.dateTime.year().month())
            result.append(RecordingSection(id: id, title: title, pieces: piecesInMonth))
        }

        return result
    }
}



