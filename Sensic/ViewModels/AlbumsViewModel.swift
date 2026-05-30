////  AlbumsViewModel.swift
//  Sensic
//
import Foundation
import Observation

@Observable
@MainActor
final class AlbumsViewModel {
    
    // MARK: - Data
    
    var albums: [Album] = []
    var allRecordings: [RecordingItem] = [
        .init(title: "Buzzkiller", duration: "4:07", date: "12:07 PM"),
        .init(title: "Ego Death At Ba...", duration: "3:19", date: "Yesterday"),
        .init(title: "Pink Light", duration: "4:11", date: "Sunday"),
        .init(title: "Stayaway", duration: "3:31", date: "Wednesday"),
        .init(title: "Downfall", duration: "4:15", date: "Apr 27, 2026"),
        .init(title: "All them horses", duration: "5:13", date: "Apr 28, 2026"),
        .init(title: "Shooting Star", duration: "3:52", date: "Apr 29, 2026")
    ]
    // MARK: - UI State
    
    var showCreateAlbum = false
    var albumName = ""
    
    // MARK: - Create Album
    
    func createAlbum() {
        
        let trimmed = albumName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        let newAlbum = Album(
            id: UUID(),
            name: trimmed,
            pieceIDs: []
        )
        
        albums.append(newAlbum)
        
        albumName = ""
        showCreateAlbum = false
    }
    
    // MARK: - Update Name
    
    func updateAlbumName(id: UUID, newName: String) {
        
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        guard let album = albums.first(where: { $0.id == id }) else { return }
        
        album.name = trimmed
    }
    
    // MARK: - Add Recordings
    
    func addRecordings(_ recordings: [RecordingItem], to album: Album) {

        guard let index = albums.firstIndex(where: { $0.id == album.id }) else { return }

        let newIDs = recordings.map(\.id)
        let existing = Set(albums[index].pieceIDs)
        let uniqueIDs = newIDs.filter { !existing.contains($0) }

        albums[index].pieceIDs.append(contentsOf: uniqueIDs)
    }
    
    // MARK: - Get Recordings for Album
    
    func recordings(for album: Album) -> [RecordingItem] {
        allRecordings.filter {
            album.pieceIDs.contains($0.id)
        }
    }

    // MARK: - Recording actions (album context)

    func renameRecording(id: UUID, title: String) -> Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        guard let index = allRecordings.firstIndex(where: { $0.id == id }) else { return false }
        allRecordings[index].title = trimmed
        return true
    }

    func removeRecording(id: UUID, fromAlbumID albumID: UUID) {
        guard let index = albums.firstIndex(where: { $0.id == albumID }) else { return }
        albums[index].pieceIDs.removeAll { $0 == id }
    }

    func moveRecording(id: UUID, fromAlbumID sourceID: UUID, toAlbumID destinationID: UUID) {
        guard sourceID != destinationID else { return }
        guard let sourceIndex = albums.firstIndex(where: { $0.id == sourceID }) else { return }
        guard let destinationIndex = albums.firstIndex(where: { $0.id == destinationID }) else { return }

        albums[sourceIndex].pieceIDs.removeAll { $0 == id }

        if !albums[destinationIndex].pieceIDs.contains(id) {
            albums[destinationIndex].pieceIDs.append(id)
        }
    }
}





