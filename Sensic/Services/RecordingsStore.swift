//
//  RecordingsStore.swift
//  Sensic
//


import Foundation
import Observation

@Observable
@MainActor
final class RecordingsStore {
    static let shared = RecordingsStore()

    private(set) var pieces: [Piece] = []
    private(set) var isLoading = false

    var toastMessage: String?

    private let piecesKey = "sensic.pieces"
    private let didSeedKey = "sensic.didSeedPreviewData"

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init() {}

    static func previewInstance() -> RecordingsStore {
        let store = RecordingsStore()
        store.seedSampleData()
        return store
    }

    func loadIfNeeded() async {
        guard pieces.isEmpty, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        if let storedPieces = loadPieces() {
            pieces = storedPieces
        }
        // Production starts with an empty library; users build it up
        // by saving recordings from CreationView.  `seedSampleData()`
        // below is still used by `previewInstance()` so SwiftUI
        // previews can render the panel with content.
    }

    func renamePiece(id: UUID, title: String) {
        guard let index = pieces.firstIndex(where: { $0.id == id }) else { return }
        pieces[index].title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        persist()
    }

    func deletePiece(id: UUID) {
        pieces.removeAll { $0.id == id }
        persist()
    }

    @discardableResult
    func savePiece(title: String,
                   duration: TimeInterval,
                   noteEvents: [NoteEvent],
                   trackSnapshots: [TrackSnapshot]? = nil) -> Piece {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let piece = Piece(
            title: trimmed.isEmpty ? "Untitled" : trimmed,
            duration: max(0, duration),
            noteEvents: noteEvents,
            trackSnapshots: trackSnapshots
        )
        pieces.insert(piece, at: 0)
        persist()
        return piece
    }

    /// Update an existing piece's content in place.  Used when the
    /// user taps Save on a recording that was already saved earlier
    /// in this session (or reopened from the library) — the title
    /// stays the same, only the musical content + duration get
    /// refreshed.  Returns the updated piece, or `nil` if no piece
    /// with that id exists in the store.
    @discardableResult
    func updatePiece(id: UUID,
                     duration: TimeInterval,
                     noteEvents: [NoteEvent],
                     trackSnapshots: [TrackSnapshot]?) -> Piece? {
        guard let index = pieces.firstIndex(where: { $0.id == id }) else {
            return nil
        }
        pieces[index].duration       = max(0, duration)
        pieces[index].noteEvents     = noteEvents
        pieces[index].trackSnapshots = trackSnapshots
        persist()
        return pieces[index]
    }

    func showToast(_ message: String) {
        toastMessage = message
    }

    func clearToast() {
        toastMessage = nil
    }

    // MARK: - Persistence

    private func persist() {
        if let data = try? encoder.encode(pieces) {
            UserDefaults.standard.set(data, forKey: piecesKey)
        }
    }

    private func loadPieces() -> [Piece]? {
        guard let data = UserDefaults.standard.data(forKey: piecesKey) else { return nil }
        return try? decoder.decode([Piece].self, from: data)
    }

    // MARK: - Sample data

    func seedSampleData() {
        let calendar = Calendar.current
        let now = Date()

        func date(daysAgo: Int, hour: Int, minute: Int) -> Date {
            let base = calendar.date(byAdding: .day, value: -daysAgo, to: now) ?? now
            return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: base) ?? base
        }

        pieces = [
            Piece(title: "Buzkiller", createdAt: date(daysAgo: 0, hour: 12, minute: 7), duration: 247),
            Piece(title: "Ego Death At Ba...", createdAt: calendar.date(byAdding: .day, value: -1, to: now) ?? now, duration: 199),
            Piece(title: "Pink Light", createdAt: date(daysAgo: 3, hour: 18, minute: 20), duration: 251),
            Piece(title: "Stayaway", createdAt: date(daysAgo: 5, hour: 21, minute: 4), duration: 211),
            Piece(title: "Midnight Run", createdAt: date(daysAgo: 24, hour: 23, minute: 11), duration: 184),
            Piece(title: "Glass Garden", createdAt: date(daysAgo: 28, hour: 10, minute: 45), duration: 222),
        ].sorted { $0.createdAt > $1.createdAt }
    }
}
