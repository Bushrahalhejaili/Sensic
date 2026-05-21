//
//  RecordingsPickerView.swift
//  Sensic
//

import SwiftUI

// MARK: - Model

struct RecordingItem: Identifiable {

    let id = UUID()
    let title: String
    let duration: String
    let date: String
}

// MARK: - View

struct RecordingsPickerView: View {

    let album: Album

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
        )
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

// MARK: - UI

extension RecordingsPickerView {

    private var topBar: some View {

        HStack {

            Button {

                dismiss()

            } label: {

                Circle()
                    .fill(
                        Color(
                            red: 20 / 255,
                            green: 25 / 255,
                            blue: 55 / 255
                        )
                    )
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

    private func recordingCard(
        _ recording: RecordingItem
    ) -> some View {

        let isSelected = selectedRecordings.contains(recording.id)

        return HStack(spacing: 14) {

            VStack(
                alignment: .leading,
                spacing: 10
            ) {

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
                        isSelected
                        ? Color.purple
                        : Color.purple.opacity(0.4),
                        lineWidth: 2
                    )
                    .frame(width: 24, height: 24)
                    .overlay {

                        if isSelected {

                            Image(systemName: "checkmark")
                                .font(
                                    .system(
                                        size: 11,
                                        weight: .bold
                                    )
                                )
                                .foregroundStyle(.purple)
                        }
                    }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    Color(
                        red: 17 / 255,
                        green: 22 / 255,
                        blue: 55 / 255
                    )
                )
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

// MARK: - Preview

#Preview {
    RecordingsPickerView(
        album: Album(
            id: UUID(),
            name: "Test Album",
            pieceIDs: []
        )
    )
}
