//
//  AlbumsView.swift
//  Sensic
//


//
//  AlbumsView.swift
//  Sensic
//



//
//  AlbumsView.swift
//  Sensic
//


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

        // iOS 17+ body-local Bindable proxy.  Lets us write
        // `$vm.showCreateAlbum` and `$vm.albumName` as proper
        // Bindings even though `vm` is held as @State (which
        // doesn't give you `$`-access directly on @Observable
        // properties).
        @Bindable var vm = vm

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
            }
            // Same reasoning as in CreationView: keep the albums
            // grid and search bar anchored to the screen edges
            // when the keyboard appears for the alert's text
            // field, rather than letting the layout shift up.  The
            // alert itself still handles its own keyboard
            // avoidance; this only affects the content underneath.
            .ignoresSafeArea(.keyboard, edges: .bottom)
            // Create-album alert — uses the native iOS alert,
            // which on iOS 26 renders with Liquid Glass, the right
            // backdrop, focus, and keyboard avoidance.  Same API
            // used in CreationView, so both views automatically
            // stay visually consistent.
            .alert("Name Album", isPresented: $vm.showCreateAlbum) {
                TextField("Name", text: $vm.albumName)

                Button("Cancel", role: .cancel) {
                    vm.albumName = ""
                }

                Button("Save") {
                    vm.createAlbum()
                }
                .disabled(
                    vm.albumName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )
            } message: {
                Text("Enter a name for this album.")
            }
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

        HStack(spacing: 10) {

            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color("tertiary"))

            Text("Search")
                .foregroundStyle(Color("tertiary"))

            Spacer()

            Image(systemName: "mic")
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 14)
        .frame(height: 50)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color("Navy"))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color("MainPurple").opacity(0.35), lineWidth: 1)
        )
        .padding(.bottom, 8)
    }
}

#Preview {
    AlbumsView()
}
