//
//  SensicApp.swift
//  Sensic
//
//  Created by Bushra Hatim Alhejaili on 12/05/2026.
//

import SwiftUI

@main
struct SensicApp: App {
    private let store = RecordingsStore.shared
    private let albumsStore = AlbumsStore.shared

    var body: some Scene {
        WindowGroup {
            HomeView(store: store, albumsStore: albumsStore)
                .environment(store)
                .environment(albumsStore)
        }
    }
}


