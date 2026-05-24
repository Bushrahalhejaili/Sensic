//
//  RecordingsPickerView.swift
//  Sensic
//
//


import SwiftUI

// MARK: - Model

struct RecordingItem: Identifiable, Equatable {
        let id = UUID()
        let title: String
        let duration: String
        let date: String
    }
// MARK: - View

struct RecordingsPickerView: View {

    let album: Album
    let onSave: ([RecordingItem]) -> Void
    
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""

    @State private var selectedRecordings: Set<UUID> = []

    let recordings: [RecordingItem] = [

        .init(
            title: "Buzzkiller",
            duration: "4:07",
            date: "12:07 PM"
        ),

        .init(
            title: "Ego Death At Ba...",
            duration: "3:19",
            date: "Yesterday"
        ),

        .init(
            title: "Pink Light",
            duration: "4:11",
            date: "Sunday"
        ),

        .init(
            title: "Stayaway",
            duration: "3:31",
            date: "Wednesday"
        ),

        .init(
            title: "Downfall",
            duration: "4:15",
            date: "Apr 27, 2026"
        ),

        .init(
            title: "All them horses",
            duration: "5:13",
            date: "Apr 28, 2026"
        ),

        .init(
            title: "Shooting Star",
            duration: "3:52",
            date: "Apr 29, 2026"
        )
    ]

    var body: some View {

        ZStack {

            Color.black
                .ignoresSafeArea()

            VStack(spacing: 22) {

                topBar

                searchBar

                recordingsList
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
        }
    }
}

// MARK: - UI

extension RecordingsPickerView {

    private var topBar: some View {

        HStack {

            Button {

                dismiss()

            } label: {

                Circle()
                    .fill(
                    (Color("MainPurple"))

                    )
                    .frame(width: 52, height: 52)
                    .overlay {

                        Image(systemName: "xmark")
                            .font(
                                .system(
                                    size: 18,
                                    weight: .medium
                                )
                            )
                            .foregroundStyle(.white)
                    }
            }

            Spacer()

            VStack(spacing: 2) {

                if selectedRecordings.isEmpty {

                    Text("Add recordings")
                        .font(
                            .system(
                                size: 22,
                                weight: .semibold
                            )
                        )
                        .foregroundStyle(.white)

                } else {

                    Text(
                        "\(selectedRecordings.count) recording\(selectedRecordings.count > 1 ? "s" : "") added to \"\(album.name)\""
                    )
                    .font(
                        .system(
                            size: 16,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                }
            }

            Spacer()

            // Check Button

            Button {

                let selectedItems = recordings.filter {
                    selectedRecordings.contains($0.id)
                }

                onSave(selectedItems)

                dismiss()

            } label: {

                Circle()
                    .fill(
                    (Color("MainPurple"))

                    )
                    .frame(width: 52, height: 52)
                    .overlay {

                        Image(systemName: "checkmark")
                            .font(
                                .system(
                                    size: 18,
                                    weight: .bold
                                )
                            )
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
        .padding(.horizontal, 16)
        .frame(height: 52)
        .background(
            Capsule()
                .fill(
                    Color.white.opacity(0.12)
                )
        )
    }

    private var recordingsList: some View {

        ScrollView(showsIndicators: false) {

            VStack(spacing: 2) {

                ForEach(recordings) { recording in

                    VStack(spacing: 16) {

                        recordingCard(recording)

                        Rectangle()
                            .fill(
                                Color.white.opacity(0.08)
                            )
                            .frame(height: 1)
                    }
                }
            }
            .padding(.top, 4)
            .padding(.bottom, 20)
        }
    }

    private func recordingCard(
        _ recording: RecordingItem
    ) -> some View {

        let isSelected =
        selectedRecordings.contains(recording.id)

        return HStack(spacing: 12) {

            VStack(
                alignment: .leading,
                spacing: 12
            ) {

                HStack {

                    Text(recording.title)
                        .font(
                            .system(
                                size: 22,
                                weight: .medium
                            )
                        )
                        .foregroundStyle(.white)

                    Spacer()

                    Text(recording.date)
                        .font(.system(size: 14))
                        .foregroundStyle(
                            .gray.opacity(0.9)
                        )
                }

                HStack(spacing: 10) {

                    Image(systemName: "waveform")
                        .foregroundStyle(
                            .white.opacity(0.9)
                        )

                    Text(recording.duration)
                        .font(.system(size: 15))
                        .foregroundStyle(.gray)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical,14 )
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(
                        Color(
                            red: 16 / 255,
                            green: 22 / 255,
                            blue: 58 / 255
                        )
                    )
            )

            Button {

                toggleSelection(recording.id)

            } label: {

                ZStack {

                    Circle()
                        .stroke(
                            isSelected
                            ? Color(
                                red: 170 / 255,
                                green: 102 / 255,
                                blue: 255 / 255
                            )
                            : Color.purple.opacity(0.45),
                            lineWidth: 2
                        )
                        .frame(width: 20, height: 20)

                    Image(
                        systemName:
                            isSelected
                        ? "checkmark"
                        : "plus"
                    )
                    .font(
                        .system(
                            size: 9,
                            weight: .bold
                        )
                    )
                    .foregroundStyle(
                        isSelected,
                        (Color("MainPurple")),

                        : Color.purple.opacity(0.8)
                    )
                }
            }
        }
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

// MARK: - Preview
#Preview {

    RecordingsPickerView(
        album: Album(
            id: UUID(),
            name: "The great divide",
            pieceIDs: []
        ),
        onSave: { _ in

        }
    )
}
