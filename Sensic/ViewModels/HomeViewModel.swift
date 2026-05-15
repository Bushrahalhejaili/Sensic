//
//  HomeViewModel.swift
//  Sensic
//

import Foundation
import Observation

@Observable
@MainActor
final class HomeViewModel {
    var recordings: [Piece] = []
    var selectedRecordingID: UUID?

    var hasRecordings: Bool { !recordings.isEmpty }
    var showsRecordingActions: Bool { selectedRecordingID != nil }

    static let previewWithList: HomeViewModel = {
        let vm = HomeViewModel()
        vm.recordings = [
            Piece(
                id: UUID(),
                title: "Buzkiller",
                createdAt: Calendar.current.date(bySettingHour: 12, minute: 7, second: 0, of: Date()) ?? Date(),
                duration: 247
            ),
            Piece(
                id: UUID(),
                title: "Ego Death At Ba...",
                createdAt: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date(),
                duration: 199
            ),
        ]
        return vm
    }()

    static let previewWithActions: HomeViewModel = {
        let vm = HomeViewModel()
        let piece = Piece(
            id: UUID(),
            title: "Ego Death At Ba...",
            createdAt: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date(),
            duration: 199
        )
        vm.recordings = [piece]
        vm.selectedRecordingID = piece.id // tap a row → Rename / Add / Delete bar
        return vm
    }()
}
