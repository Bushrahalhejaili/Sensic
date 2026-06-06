//
//  RecordingsPickerView.swift
//  Sensic
//
//
//  RecordingsPickerView.swift
//  Sensic
//

import SwiftUI

// MARK: - View

struct RecordingsPickerView: View {

    let album: Album
    let recordings: [RecordingItem]
    let onSave: ([RecordingItem]) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""
    @State private var selectedRecordings: Set<UUID> = []

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
            glassCircleButton(
                icon: "xmark",
                iconSize: 18,
                iconColor: .white
            ) {
                dismiss()
            }

            Spacer()

            VStack(spacing: 2) {
                if selectedRecordings.isEmpty {
                    Text("Add recordings")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                } else {
                    Text("\(selectedRecordings.count) recording\(selectedRecordings.count > 1 ? "s" : "") added to \"\(album.name)\"")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
            }

            Spacer()

            purpleCircleButton {
                let selectedItems = recordings.filter { selectedRecordings.contains($0.id) }
                onSave(selectedItems)
                dismiss()
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
                .fill(Color.white.opacity(0.12))
        )
    }

    private var recordingsList: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 2) {
                ForEach(filteredRecordings) { recording in
                    VStack(spacing: 16) {
                        recordingCard(recording)
                        Rectangle()
                            .fill(Color.white.opacity(0.08))
                            .frame(height: 1)
                    }
                }
            }
            .padding(.top, 4)
            .padding(.bottom, 20)
        }
    }

    private var filteredRecordings: [RecordingItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        let all = recordings

        guard !query.isEmpty else { return all }

        return all.filter {
            $0.title.localizedCaseInsensitiveContains(query)
            || $0.duration.localizedCaseInsensitiveContains(query)
            || $0.date.localizedCaseInsensitiveContains(query)
        }
    }

    private func recordingCard(_ recording: RecordingItem) -> some View {
        let isSelected = selectedRecordings.contains(recording.id)

        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(recording.title)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(.white)

                    Spacer()

                    Text(recording.date)
                        .font(.system(size: 14))
                        .foregroundStyle(.gray.opacity(0.9))
                }

                HStack(spacing: 10) {
                    Image(systemName: "waveform")
                        .foregroundStyle(.white.opacity(0.9))

                    Text(recording.duration)
                        .font(.system(size: 15))
                        .foregroundStyle(.gray)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(Color(red: 16/255, green: 22/255, blue: 58/255))
            )

            Button {
                toggle(recording)
            } label: {
                ZStack {
                    Circle()
                        .stroke(
                            isSelected
                            ? Color("MainPurple")
                            : Color("MainPurple"),
                            lineWidth: 2
                        )
                        .frame(width: 20, height: 20)

                    Image(systemName: isSelected ? "checkmark" : "plus")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(
                            isSelected ? Color("MainPurple") : Color("MainPurple")
                        )
                }
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Toggle

extension RecordingsPickerView {

    private func toggle(_ recording: RecordingItem) {
        if selectedRecordings.contains(recording.id) {
            selectedRecordings.remove(recording.id)
        } else {
            selectedRecordings.insert(recording.id)
        }
    }
}

// MARK: - Actions

extension RecordingsPickerView {

    private func glassCircleButton(
        icon: String,
        iconSize: CGFloat,
        iconColor: Color = .white,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(Color("SpaceBlue"))
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private func purpleCircleButton(
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: "checkmark")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(Color("MainPurple"))
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    let vm = AlbumsViewModel()

    RecordingsPickerView(
        album: Album(
            id: UUID(),
            name: "The great divide",
            pieceIDs: []
        ),
        recordings: vm.allRecordingsForPicker(),
        onSave: { _ in }
    )
}
