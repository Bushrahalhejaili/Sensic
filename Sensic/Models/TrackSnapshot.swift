//
//  TrackSnapshot.swift
//  Sensic
//
//  Created by Bushra Hatim Alhejaili on 30/05/2026.
//

import Foundation

// MARK: - TrackSnapshot

/// A pure-data copy of a track's musical content, used by the
/// Copy/Paste workflow.  Lives independently of any TrackRecorder
/// instance so we can hold it on the clipboard while the original
/// keeps recording.
struct TrackSnapshot {
    let notes: [RecordedNote]
    let duration: TimeInterval
    let name: String
}
