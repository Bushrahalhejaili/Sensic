//
//  AlbumsView.swift
//  Sensic
//


import SwiftUI
import Observation

struct AlbumsView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var albumsStore: AlbumsStore
    @Bindable var recordingsStore: RecordingsStore
    @State private var vm: AlbumsViewModel
    @State private var searchText = ""

    init(
        albumsStore: AlbumsStore = .shared,
        recordingsStore: RecordingsStore = .shared
    ) {
        _albumsStore = Bindable(wrappedValue: albumsStore)
        _recordingsStore = Bindable(wrappedValue: recordingsStore)
        _vm = State(
            initialValue: AlbumsViewModel(
                albumsStore: albumsStore,
                recordingsStore: recordingsStore
            )
        )
    }
    
    var body: some View {
        
            ZStack {
                
                Color.black
                    .ignoresSafeArea()
                
                VStack(alignment: .leading, spacing: 0) {
                    
                    topBar
                    titleSection
                    
                    if albumsStore.albums.isEmpty {
                        emptyState
                    } else {
                        albumsContent
                    }
                    
                    Spacer()
                    searchBar
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 8)
                
                // Popup
                if vm.showCreateAlbum {
                    
                    CreateAlbumView(vm: vm)
                        .frame(maxWidth: 380)
                        .transition(.scale.combined(with: .opacity))
                        .zIndex(1)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: vm.showCreateAlbum)
            .navigationBarBackButtonHidden(true)
            .onAppear {
                if albumsStore.shouldPresentCreateOnAlbumsAppear {
                    vm.showCreateAlbum = true
                    albumsStore.shouldPresentCreateOnAlbumsAppear = false
                }
            }

        }
    }

// MARK: - Sections

extension AlbumsView {

    private var topBar: some View {

        HStack {
            SensicGlassCircleButton(
                systemName: "chevron.left",
                iconSize: 16,
                iconColor: .white,
                action: { dismiss() }
            )

            Spacer()

            SensicGlassCircleButton(
                systemName: "plus",
                iconSize: 18,
                iconColor: Color("MainPurple"),
                action: { vm.showCreateAlbum = true }
            )
        }
    }

    private var titleSection: some View {

        VStack(alignment: .leading, spacing: 4) {

            Text("Albums")
                .font(.system(size: 42, weight: .bold))
                .foregroundStyle(.white)

            Text("\(albumsStore.albums.count) Albums")
                .font(.system(size: 17))
                .foregroundStyle(Color("tertiary"))
        }
        .padding(.top, 14)
    }

    private var emptyState: some View {

        VStack(spacing: 10) {

            Spacer()

            Text("You dont have any albums yet")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)

            Text("Click the plus button\nto creat one.")
                .multilineTextAlignment(.center)
                .font(.system(size: 16))
                .foregroundStyle(Color("tertiary"))

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var albumsContent: some View {

        ScrollView(showsIndicators: false) {

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 14),
                    GridItem(.flexible(), spacing: 14)
                ],
                spacing: 14
            ) {

                ForEach(albumsStore.albumsNewestFirst, id: \.id) { album in

                    NavigationLink {

                        AlbumDetailsView(vm: vm, albumID: album.id)
                            .navigationBarBackButtonHidden(true)

                    } label: {

                        albumCard(album)
                    }
                }
            }
            .padding(.top, 24)
        }
    }
//
    private func albumCard(_ album: Album) -> some View {

        VStack(alignment: .leading, spacing: 14) {

           // Spacer()

            Text(album.name)
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(.white)

            Divider()
                .overlay(Color.white.opacity(0.15))

            Text("\(album.pieceIDs.count) Recordings")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.7))
        }
        .padding(18)
        .frame(height: 140)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    Color(
                        red: 45 / 255,
                        green: 51 / 255,
                        blue: 85 / 255
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color("MainPurple").opacity(0.35), lineWidth: 1)
        )
    }

    private var searchBar: some View {
        SensicSearchBar(text: $searchText)
            .padding(.bottom, 8)
    }
}

#Preview {
    AlbumsView()
}
