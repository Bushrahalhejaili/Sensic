//
//  PracticeViewModel.swift
//  Sensic
//
//  Created by شهد عبدالله القحطاني on 01/12/1447 AH.
//

import Foundation
import Combine

@MainActor
final class PracticeViewModel: ObservableObject {

    @Published var sessions = [PracticeSession]()

    // ─────────────────────────────────────────
    // MARK: - CRUD
    // ─────────────────────────────────────────

    func addSession(_ session: PracticeSession) {
        sessions.insert(session, at: 0)
    }

    func deleteSession(id: UUID) {
        sessions.removeAll { $0.id == id }
    }

    // ─────────────────────────────────────────
    // MARK: - Stats
    // ─────────────────────────────────────────

    var totalNotes: Int {
        sessions.reduce(0) { $0 + $1.noteEvents.count }
    }

    var avgAccuracy: Int {
        guard !sessions.isEmpty else { return 0 }
        return Int(sessions.reduce(0) { $0 + $1.accuracy } / Double(sessions.count) * 100)
    }

    // ─────────────────────────────────────────
    // MARK: - API (فعّلها لما السيرفر يكون جاهز)
    // ─────────────────────────────────────────

    // func fetchSessions() async {
    //     sessions = (try? await PracticeService.shared.getAll()) ?? []
    // }
    //
    // func saveSession(_ session: PracticeSession) async {
    //     if let saved = try? await PracticeService.shared.save(session: session) {
    //         sessions.insert(saved, at: 0)
    //     }
    // }
    //
    // func deleteSessionRemote(id: UUID) async {
    //     try? await PracticeService.shared.delete(id: id)
    //     sessions.removeAll { $0.id == id }
    // }
}



