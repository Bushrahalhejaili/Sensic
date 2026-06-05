//
//  AddToAlbumPickerView.swift
//  Sensic
//

import SwiftUI

struct AddToAlbumPickerView: View {
    let piece: Piece
    @Bindable var albumsStore: AlbumsStore
    let recordingsStore: RecordingsStore
    let onFinished: () -> Void
    var onCancel: () -> Void = {}

    @State private var searchText = ""
    @State private var selectedAlbumIDs: Set<UUID> = []
    @State private var initialAlbumIDs: Set<UUID> = []
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 22) {
                topBar
                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color("RecordingRed"))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
                searchBar
                albumsGrid
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
        }
        .onAppear {
            let existing = albumsStore.albumIDs(containingPieceID: piece.id)
            initialAlbumIDs = existing
            selectedAlbumIDs = existing
        }
    }

    private var topBar: some View {
        HStack {
            SensicGlassCircleButton(
                systemName: "xmark",
                iconSize: 18,
                iconColor: .white,
                action: { onCancel() }
            )

            Spacer()

            VStack(spacing: 2) {
                if selectedAlbumIDs.isEmpty {
                    Text("Add to album")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                } else {
                    Text(statusLine)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
            }

            Spacer()

            SensicGlassCircleButton(
                systemName: "checkmark",
                iconSize: 18,
                iconColor: Color("MainPurple"),
                action: confirmSave
            )
        }
    }

    private var statusLine: String {
        let count = selectedAlbumIDs.count
        let noun = count == 1 ? "recording" : "recordings"
        if count == 1,
           let name = albumsStore.albums.first(where: { selectedAlbumIDs.contains($0.id) })?.name {
            return "1 \(noun) added to \"\(name)\""
        }
        return "\(count) \(noun) added to album\(count == 1 ? "" : "s")"
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.gray)

            TextField("Search", text: $searchText)
                .foregroundStyle(.white)

            Spacer()

            Image(systemName: "mic.fill")
                .foregroundStyle(.white.opacity(0.8))
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.12))
        )
    }

    private var albumsGrid: some View {
        ScrollView(showsIndicators: false) {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 14),
                    GridItem(.flexible(), spacing: 14),
                ],
                spacing: 14
            ) {
                ForEach(filteredAlbums, id: \.id) { album in
                    albumCard(album)
                }
            }
            .padding(.top, 4)
            .padding(.bottom, 20)
        }
    }

    private var filteredAlbums: [Album] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return albumsStore.albumsNewestFirst }
        return albumsStore.albumsNewestFirst.filter {
            $0.name.localizedCaseInsensitiveContains(query)
        }
    }

    private func albumCard(_ album: Album) -> some View {
        let isSelected = selectedAlbumIDs.contains(album.id)
        return VStack(alignment: .leading, spacing: 14) {
            Text(album.name)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)

            Divider()
                .overlay(Color.white.opacity(0.15))

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(album.pieceIDs.count) Recordings")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.7))

                    if isSelected {
                        Text("Selected")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color("tertiary"))
                    }
                }

                Spacer()

                Button {
                    toggleAlbum(album)
                } label: {
                    ZStack {
                        Circle()
                            .stroke(
                                isSelected
                                ? Color(red: 170 / 255, green: 102 / 255, blue: 255 / 255)
                                : Color.purple.opacity(0.45),
                                lineWidth: 2
                            )
                            .frame(width: 20, height: 20)

                        Image(systemName: isSelected ? "checkmark" : "plus")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(
                                isSelected ? Color("MainPurple") : Color.purple.opacity(0.8)
                            )
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .frame(height: 140)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    Color(
                        red: 45 / 255,
                        green: 51 / 255,
                        blue: 85 / 255
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color("MainPurple").opacity(0.35), lineWidth: 1)
        )
        // Make the whole card tappable to toggle selection
        .contentShape(Rectangle())
        .onTapGesture {
            toggleAlbum(album)
        }
    }

    private func toggleAlbum(_ album: Album) {
        errorMessage = nil
        if selectedAlbumIDs.contains(album.id) {
            selectedAlbumIDs.remove(album.id)
        } else {
            selectedAlbumIDs.insert(album.id)
        }
    }

    private func confirmSave() {
        errorMessage = nil
        AlbumAddToAlbumLogic.finish(
            piece: piece,
            albumIDs: selectedAlbumIDs,
            albumsStore: albumsStore,
            recordingsStore: recordingsStore
        )
        onFinished()
    }
}

#Preview {
    AddToAlbumPickerView(
        piece: Piece(title: "Pink Light", duration: 251),
        albumsStore: AlbumsStore.previewInstance(),
        recordingsStore: .previewInstance(),
        onFinished: {}
    )
}
