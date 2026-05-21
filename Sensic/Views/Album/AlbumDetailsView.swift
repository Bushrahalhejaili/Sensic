//
//  AlbumDetailsView.swift
//  Sensic
//
//  Created by Maram Ibrahim  on 04/12/1447 AH.
//
////
//  AlbumDetailsView.swift
//  Sensic
//

import SwiftUI

struct AlbumDetailsView: View {

    let vm: AlbumsViewModel
    let album: Album
    
    @Environment(\.dismiss) private var dismiss

    @State private var showRecordingsPicker = false

    @State private var isEditingTitle = false
    @State private var albumName = ""

    @FocusState private var isTextFieldFocused: Bool

    var body: some View {

        ZStack {

            Color(
                red: 45 / 255,
                green: 51 / 255,
                blue: 85 / 255
            )
            .ignoresSafeArea()

            VStack(
                alignment: .leading,
                spacing: 16
            ) {

                topBar

                titleSection

                Divider()
                    .overlay(Color.white.opacity(0.15))

                Text("\(album.pieceIDs.count) Recordings")
                    .foregroundStyle(.white.opacity(0.72))
                    .font(.system(size: 18, weight: .medium))

                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: .topLeading
            )
        }

        .sheet(isPresented: $showRecordingsPicker) {

            RecordingsPickerView(album: album)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
        }

        .onAppear {

            albumName = album.name
        }
    }
}

// MARK: - UI

extension AlbumDetailsView {

    private var topBar: some View {

        HStack {

            // Back

            Button {

                dismiss()

            } label: {

                glassButton(
                    icon: "chevron.left",
                    color: .white
                )
            }

            Spacer()

            HStack(spacing: 12) {

                // Add Recordings

                Button {

                    showRecordingsPicker = true

                } label: {

                    glassButton(
                        icon: "plus",
                        color: Color("MainPurple")
                    )
                }

                // Edit / Save

                Button {

                    if isEditingTitle {
                        vm.updateAlbumName(id: album.id, newName: albumName)
                    }

                    withAnimation(.easeInOut(duration: 0.2)) {
                        isEditingTitle.toggle()
                    }

                    isTextFieldFocused = false

                } label: {

                    glassButton(
                        icon: isEditingTitle ? "checkmark" : "pencil",
                        color: isEditingTitle ? .white : Color("MainPurple"),
                        backgroundColor: isEditingTitle
                            ? Color(red: 170/255, green: 110/255, blue: 205/255)
                            : Color.black.opacity(0.25)
                    )
                
                }
            }
        }
    }
    private var titleSection: some View {

        VStack(
            alignment: .leading,
            spacing: 0
        ) {

            if isEditingTitle {

                TextField(
                    "",
                    text: $albumName,
                    axis: .vertical
                )
                .focused($isTextFieldFocused)
                .font(.system(size: 56, weight: .bold))
                .foregroundStyle(
                    Color(
                        red: 198 / 255,
                        green: 224 / 255,
                        blue: 255 / 255
                    )
                )
                .tint(.blue)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 28)
                        .fill(
                            Color(
                                red: 28 / 255,
                                green: 35 / 255,
                                blue: 78 / 255
                            )
                        )
                )

            } else {

                Text(albumName)
                    .font(.system(size: 56, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
            }
        }
    }

    private func glassButton(
        icon: String,
        color: Color,
        backgroundColor: Color = Color.black.opacity(0.25)
    ) -> some View {

        ZStack {

            Circle()
                .fill(.ultraThinMaterial)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.08),
                            Color.black.opacity(0.18)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Apply customizable background tint layer beneath stroke and icon
            Circle()
                .fill(backgroundColor)

            Circle()
                .stroke(
                    Color.white.opacity(0.14),
                    lineWidth: 1
                )

            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.system(size: 16, weight: .semibold))
        }
        .frame(width: 46, height: 46)
    }
}

// MARK: - Preview

#Preview {

    AlbumDetailsView(
        vm: AlbumsViewModel(),
        album: Album(
            id: UUID(),
            name: "The great divide",
            pieceIDs: []
        )
    )
}

