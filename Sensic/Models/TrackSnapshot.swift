//
//  TrackSnapshot.swift
//  Sensic
//
//  Created by Bushra Hatim Alhejaili on 30/05/2026.
//

import Foundation

// MARK: - TrackSnapshot

/// A pure-data copy of a track's musical content + position on
/// the timeline.  Two consumers:
///
/// 1. The in-session Copy/Paste workflow — held briefly on the
///    clipboard while the user is composing.  Only `notes`,
///    `duration`, and `name` matter in this case; the layout
///    fields default to 0 because the consumer (`MainTimelineView`)
///    chooses a fresh row + start position for the paste.
///
/// 2. Persistence inside a saved `Piece` — captures the full
///    timeline state per track so reopening a recording restores
///    every track exactly where the user left it.
struct TrackSnapshot: Codable, Equatable {
    let notes: [RecordedNote]
    let duration: TimeInterval
    let name: String
    var trackStartSec: TimeInterval = 0
    var trackRow: Int = 0
}
