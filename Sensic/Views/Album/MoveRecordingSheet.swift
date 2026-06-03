//
//  MoveRecordingSheet.swift
//  Sensic
//

import SwiftUI

struct MoveRecordingSheet: View {
    let recording: RecordingItem
    let currentAlbumID: UUID
    let albums: [Album]
    let onMove: (UUID) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 10) {
                        if destinationAlbums.isEmpty {
                            Text("No other albums yet")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(Color("tertiary"))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 32)
                        } else {
                            ForEach(destinationAlbums) { album in
                                Button {
                                    onMove(album.id)
                                    dismiss()
                                } label: {
                                    albumRow(album)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .preferredColorScheme(.dark)
            .navigationTitle("Move to album")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color("MainPurple"))
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var destinationAlbums: [Album] {
        albums
            .filter { $0.id != currentAlbumID }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private func albumRow(_ album: Album) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(album.name)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text("\(album.pieceIDs.count) Recordings")
                    .font(.system(size: 13))
                    .foregroundStyle(Color("tertiary"))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color("MainPurple"))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color("SpaceBlue"))
        )
    }
}



