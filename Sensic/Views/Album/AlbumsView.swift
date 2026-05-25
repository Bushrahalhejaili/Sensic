//
//  AlbumsView.swift
//  Sensic
//


import SwiftUI
import Observation

struct AlbumsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var vm = AlbumsViewModel()
    
    var body: some View {
        
            ZStack {
                
                Color.black
                    .ignoresSafeArea()
                
                VStack(alignment: .leading, spacing: 0) {
                    
                    topBar
                    titleSection
                    
                    if vm.albums.isEmpty {
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
        }
    }

// MARK: - Sections

extension AlbumsView {

    private var topBar: some View {

        HStack {

            Button {

                dismiss()

            } label: {

                Circle()
                    .fill(Color("Navy"))
                    .frame(width: 42, height: 42)
                    .overlay {

                        Image(systemName: "chevron.left")
                            .foregroundStyle(.white)
                            .font(.system(size: 16, weight: .semibold))
                    }
            }

            Spacer()

            Button {

                vm.showCreateAlbum = true

            } label: {

                Circle()
                    .fill(Color("Navy"))
                    .frame(width: 42, height: 42)
                    .overlay {

                        Image(systemName: "plus")
                            .foregroundStyle(Color("MainPurple"))
                            .font(.system(size: 18, weight: .bold))
                    }
            }
        }
    }

    private var titleSection: some View {

        VStack(alignment: .leading, spacing: 4) {

            Text("Albums")
                .font(.system(size: 42, weight: .bold))
                .foregroundStyle(.white)

            Text("\(vm.albums.count) Albums")
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

                ForEach(vm.albums, id: \.id) { album in

                    NavigationLink {

                        AlbumDetailsView(vm: vm, albumID: album.id)
                    } label: {

                        albumCard(album)
                    }
                }
            }
            .padding(.top, 24)
        }
    }

    private func albumCard(_ album: Album) -> some View {

        VStack(alignment: .leading, spacing: 14) {

            Spacer()

            Text(album.name)
                .font(.system(size: 22, weight: .bold))
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

