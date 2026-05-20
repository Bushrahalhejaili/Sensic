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
}

// MARK: - Sections

extension AlbumsView {

    private var topBar: some View {

        HStack {

            Button {

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

                        AlbumDetailsView(album: album)

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

// MARK: - Create Album Popup
private struct CreateAlbumView: View {

    @Bindable var vm: AlbumsViewModel

    var body: some View {

        VStack(spacing: 22) {

            VStack(alignment: .leading, spacing: 10) {

                Text("Name Album")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)

                Text("Enter a name for this album.")
                    .foregroundStyle(Color("tertiary"))

                TextField("", text: $vm.albumName)
                    .foregroundStyle(.white)
                    .padding()
                    .background(
                        Capsule()
                            .fill(Color("Navy"))
                    )
            }

            HStack(spacing: 14) {

                Button {
                    vm.showCreateAlbum = false
                } label: {
                    Text("Cancel")
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Capsule().fill(Color("Navy")))
                        .foregroundStyle(.white)
                }

                Button {
                    vm.createAlbum()
                } label: {
                    Text("Save")
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Capsule().fill(Color("Lavender").opacity(0.35)))
                        .foregroundStyle(.white)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 34)
                .fill(Color("Navy"))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 34)
                .stroke(Color("MainPurple").opacity(0.35), lineWidth: 1)
        )
        .padding(.horizontal, 18)
    }
}

// MARK: - Album Details

struct AlbumDetailsView: View {

    let album: Album

    @State private var showRecordingsStore = false

    var body: some View {

        ZStack {

            Color(
                red: 45 / 255,
                green: 51 / 255,
                blue: 85 / 255
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 16) {

                HStack {

                    Circle()
                        .fill(Color("Navy"))
                        .frame(width: 42, height: 42)
                        .overlay {

                            Image(systemName: "chevron.left")
                                .foregroundStyle(.white)
                        }

                    Spacer()

                    HStack(spacing: 12) {

                        Circle()
                            .fill(Color("Navy"))
                            .frame(width: 42, height: 42)
                            .overlay {

                                Image(systemName: "plus")
                                    .foregroundStyle(Color("MainPurple"))
                            }
                            .onTapGesture {

                                showRecordingsStore = true
                            }

                        Circle()
                            .fill(Color("Navy"))
                            .frame(width: 42, height: 42)
                            .overlay {

                                Image(systemName: "pencil")
                                    .foregroundStyle(.white)
                            }
                    }
                }

                Text(album.name)
                    .font(.system(size: 56, weight: .bold))
                    .foregroundStyle(.white)

                Divider()
                    .overlay(Color.white.opacity(0.2))

                Text("\(album.pieceIDs.count) Recordings")
                    .foregroundStyle(.white.opacity(0.75))
                    .font(.system(size: 18, weight: .medium))

                Spacer()
            }
            .padding(24)
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: .topLeading
            )
        }
      
    }
}

// MARK: - Recordings Picker

struct RecordingItem: Identifiable {

    let id = UUID()
    let title: String
    let duration: String
    let date: String
}

struct RecordingsPickerView: View {

    let album: Album

    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""

    @State private var selectedRecordings: Set<UUID> = []

    let recordings: [RecordingItem] = [

        .init(title: "Buzzkiller", duration: "4:07", date: "12:07 PM"),
        .init(title: "Pink Light", duration: "4:11", date: "Sunday"),
        .init(title: "Stayaway", duration: "3:31", date: "Wednesday"),
        .init(title: "Downfall", duration: "4:15", date: "Apr 27, 2026"),
        .init(title: "All them horses", duration: "5:13", date: "Apr 28, 2026")
    ]

    var body: some View {

        ZStack {

            Color.black
                .ignoresSafeArea()

            VStack(spacing: 20) {

                topBar

                searchBar

                recordingsList

                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
        }
    }
}

// MARK: - Picker UI

extension RecordingsPickerView {

    private var topBar: some View {

        HStack {

            Button {

                dismiss()

            } label: {

                Circle()
                    .fill(Color(red: 20/255, green: 25/255, blue: 55/255))
                    .frame(width: 42, height: 42)
                    .overlay {

                        Image(systemName: "xmark")
                            .foregroundStyle(.white)
                    }
            }

            Spacer()

            Text("Add recordings")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)

            Spacer()

            Button {

                dismiss()

            } label: {

                Circle()
                    .fill(Color.purple.opacity(0.85))
                    .frame(width: 42, height: 42)
                    .overlay {

                        Image(systemName: "checkmark")
                            .foregroundStyle(.white)
                    }
            }
        }
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
        .padding(.horizontal, 14)
        .frame(height: 48)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.1))
        )
    }

    private var recordingsList: some View {

        ScrollView(showsIndicators: false) {

            VStack(spacing: 14) {

                ForEach(recordings) { recording in

                    recordingCard(recording)
                }
            }
            .padding(.top, 8)
        }
    }

    private func recordingCard(_ recording: RecordingItem) -> some View {

        let isSelected = selectedRecordings.contains(recording.id)

        return HStack(spacing: 14) {

            VStack(alignment: .leading, spacing: 10) {

                HStack {

                    Text(recording.title)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(.white)

                    Spacer()

                    Text(recording.date)
                        .font(.system(size: 13))
                        .foregroundStyle(.gray)
                }

                HStack(spacing: 10) {

                    Image(systemName: "waveform")
                        .foregroundStyle(.white.opacity(0.85))

                    Text(recording.duration)
                        .font(.system(size: 14))
                        .foregroundStyle(.gray)
                }
            }

            Button {

                toggleSelection(recording.id)

            } label: {

                Circle()
                    .stroke(
                        isSelected ? Color.purple : Color.purple.opacity(0.4),
                        lineWidth: 2
                    )
                    .frame(width: 24, height: 24)
                    .overlay {

                        if isSelected {

                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.purple)
                        }
                    }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(red: 17/255, green: 22/255, blue: 55/255))
        )
    }
}

// MARK: - Actions

extension RecordingsPickerView {

    private func toggleSelection(_ id: UUID) {

        if selectedRecordings.contains(id) {

            selectedRecordings.remove(id)

        } else {

            selectedRecordings.insert(id)
        }
    }
}

#Preview {
    AlbumsView()
}
