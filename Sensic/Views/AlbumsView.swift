//
//  AlbumsView.swift
//  Sensic
//

import SwiftUI
import Observation

struct AlbumsView: View {

    @State private var vm = AlbumsViewModel()

    var body: some View {

        NavigationStack {

            ZStack {

                SensicColors.background
                    .ignoresSafeArea()

                VStack(
                    alignment: .leading,
                    spacing: 0
                ) {

                    topBar

                    titleSection

                    if vm.albums.isEmpty {

                        emptyState

                    } else {

                        albumsGrid
                    }

                    Spacer()

                    searchBar
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 8)

                if vm.showCreateAlbum {

                    CreateAlbumView(vm: vm)
                }
            }
        }
    }
}

// MARK: - UI

extension AlbumsView {

    private var topBar: some View {

        HStack {

            Button {

            } label: {

                Circle()
                    .fill(
                        SensicColors.libraryButtonFill
                    )
                    .frame(
                        width: 42,
                        height: 42
                    )
                    .overlay {

                        Image(
                            systemName: "chevron.left"
                        )
                        .foregroundStyle(.white)
                    }
            }

            Spacer()

            Button {

                vm.showCreateAlbum = true

            } label: {

                Circle()
                    .fill(
                        SensicColors.libraryButtonFill
                    )
                    .frame(
                        width: 42,
                        height: 42
                    )
                    .overlay {

                        Image(systemName: "plus")
                            .foregroundStyle(
                                SensicColors.accentPurple
                            )
                    }
            }
        }
    }

    private var titleSection: some View {

        VStack(
            alignment: .leading,
            spacing: 4
        ) {

            Text("Albums")
                .font(
                    .system(
                        size: 42,
                        weight: .bold
                    )
                )
                .foregroundStyle(.white)

            Text("\(vm.albums.count) Albums")
                .foregroundStyle(
                    SensicColors.secondaryText
                )
        }
        .padding(.top, 16)
    }

    private var emptyState: some View {

        VStack(spacing: 12) {

            Spacer()

            Text(
                "You dont have any albums yet"
            )
            .font(
                .system(
                    size: 20,
                    weight: .semibold
                )
            )
            .foregroundStyle(.white)

            Text(
                "Click the plus button\nto creat one."
            )
            .multilineTextAlignment(.center)
            .foregroundStyle(
                SensicColors.secondaryText
            )

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var albumsGrid: some View {

        ScrollView(
            showsIndicators: false
        ) {

            LazyVGrid(
                columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ],
                spacing: 14
            ) {

                ForEach(vm.albums) { album in

                    NavigationLink {

                        AlbumDetailsView(
                            album: album
                        )

                    } label: {

                        albumCard(album)
                    }
                }
            }
            .padding(.top, 24)
        }
    }

    private func albumCard(
        _ album: Album
    ) -> some View {

        VStack(
            alignment: .leading,
            spacing: 14
        ) {

            Spacer()

            Text(album.name)
                .font(
                    .system(
                        size: 22,
                        weight: .bold
                    )
                )
                .foregroundStyle(.white)

            Divider()
                .overlay(
                    Color.white.opacity(0.15)
                )

            Text(
                "\(album.pieceIDs.count) Recordings"
            )
            .foregroundStyle(
                Color.white.opacity(0.7)
            )
        }
        .padding(18)
        .frame(height: 140)
        .frame(maxWidth: .infinity)
        .background(

            RoundedRectangle(
                cornerRadius: 24
            )
            .fill(
                Color("Indigo")            )
        )
        .overlay(

            RoundedRectangle(
                cornerRadius: 24
            )
            .stroke(
                SensicColors.cardBorder,
                lineWidth: 1
            )
        )
    }

    private var searchBar: some View {

        HStack(spacing: 10) {

            Image(
                systemName: "magnifyingglass"
            )
            .foregroundStyle(
                SensicColors.secondaryText
            )

            Text("Search")
                .foregroundStyle(
                    SensicColors.secondaryText
                )

            Spacer()

            Image(systemName: "mic")
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 14)
        .frame(height: 50)
        .background(

            RoundedRectangle(
                cornerRadius: 18
            )
            .fill(
                SensicColors.libraryButtonFill
            )
        )
        .overlay(

            RoundedRectangle(
                cornerRadius: 18
            )
            .stroke(
                SensicColors.cardBorder,
                lineWidth: 1
            )
        )
    }
}

// MARK: - Popup

private struct CreateAlbumView: View {

    @Bindable var vm: AlbumsViewModel

    var body: some View {

        ZStack {

            Color.black.opacity(0.45)
                .ignoresSafeArea()

            VStack(
                alignment: .leading,
                spacing: 20
            ) {

                VStack(
                    alignment: .leading,
                    spacing: 8
                ) {

                    Text("Name Album")
                        .font(
                            .system(
                                size: 22,
                                weight: .bold
                            )
                        )
                        .foregroundStyle(.white)

                    Text(
                        "Enter a name for this album."
                    )
                    .foregroundStyle(
                        SensicColors.secondaryText
                    )
                }

                TextField(
                    "Name",
                    text: $vm.albumName
                )
                .foregroundStyle(.white)
                .padding()
                .background(

                    Capsule()
                        .fill(
                            SensicColors.libraryButtonFill
                        )
                )

                HStack(spacing: 14) {

                    Button {

                        vm.showCreateAlbum = false

                    } label: {

                        Text("Cancel")
                            .foregroundStyle(.white)
                            .frame(
                                maxWidth: .infinity
                            )
                            .frame(height: 52)
                            .background(

                                Capsule()
                                    .fill(
                                        SensicColors.libraryButtonFill
                                    )
                            )
                    }

                    Button {

                        vm.createAlbum()

                    } label: {

                        Text("Save")
                            .foregroundStyle(.white)
                            .frame(
                                maxWidth: .infinity
                            )
                            .frame(height: 52)
                            .background(

                                Capsule()
                                    .fill(
                                Color("TransparentSpaceBlue")                                            .opacity(0.3)
                                    )
                            )
                    }
                }
            }
            .padding(24)
            .frame(width: 340)
            .background(

                RoundedRectangle(
                    cornerRadius: 32
                )
                .fill(Color.black)            )
            .overlay(

                RoundedRectangle(
                    cornerRadius: 32
                )
                .stroke(
                    SensicColors.cardBorder,
                    lineWidth: 1
                )
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
// MARK: - Details
struct AlbumDetailsView: View {

    let album: Album

    var body: some View {

        ZStack {

            Color("Indigo")
                .ignoresSafeArea()

            VStack(
                alignment: .leading,
                spacing: 0
            ) {

                HStack {

                    Button {
                      //  .buttonStyle(.glassProminent)
                    } label: {

                        Circle()
                            .fill(
                                SensicColors.libraryButtonFill
                            )
                            .frame(
                                width: 42,
                                height: 42
                            )
                            .overlay {

                                Image(
                                    systemName: "chevron.left"
                                )
                                .foregroundStyle(.white)
                            }
                    }

                    Spacer()

                    HStack(spacing: 12) {

                        Circle()
                            .fill(
                                SensicColors.libraryButtonFill
                            )
                            .frame(
                                width: 42,
                                height: 42
                            )
                            .overlay {

                                Image(systemName: "plus")
                                    .foregroundStyle(
                                        SensicColors.accentPurple
                                    )
                            }

                        Circle()
                            .fill(
                                SensicColors.libraryButtonFill
                            )
                            .frame(
                                width: 42,
                                height: 42
                            )
                            .overlay {

                                Image(systemName: "pencil")
                                    .foregroundStyle(.white)
                            }
                    }
                }

                VStack(
                    alignment: .leading,
                    spacing: 4
                ) {

                    Text(album.name)
                        .font(
                            .system(
                                size: 42,
                                weight: .bold
                            )
                        )
                        .foregroundStyle(.white)

                    Text(
                        "\(album.pieceIDs.count) Recordings"
                    )
                    .foregroundStyle(
                        SensicColors.secondaryText
                    )
                }
                .padding(.top, 18)

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
        }
    }
}
#Preview {
    AlbumsView()
}

