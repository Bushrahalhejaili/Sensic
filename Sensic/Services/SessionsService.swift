//
//  SessionsService.swift
//  Sensic
//
//  Created by Bushra Hatim Alhejaili on 30/05/2026.
//


import Foundation

final class SessionsService {
    static let shared = SessionsService()
    private let client = APIClient.shared
    private init() {}

    func create(title: String) async throws -> PracticeSession {
        try await client.post("sessions", body: PracticeSession(title: title))
    }

    func getAll() async throws -> [PracticeSession] {
        try await client.get("sessions")
    }

    func get(id: UUID) async throws -> PracticeSession {
        try await client.get("sessions/\(id.uuidString)")
    }

    func save(session: PracticeSession) async throws -> PracticeSession {
        try await client.post("sessions/\(session.id.uuidString)", body: session)
    }

    func delete(id: UUID) async throws {
        try await client.delete("sessions/\(id.uuidString)")
    }

    func addNote(sessionId: UUID, note: NoteEvent) async throws {
        struct Body: Encodable { let note: NoteEvent }
        let _: PracticeSession = try await client.post(
            "sessions/\(sessionId.uuidString)/notes",
            body: Body(note: note)
        )
    }
}
