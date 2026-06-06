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

    private enum Layout {
        static let horizontalPadding: CGFloat = 18
        static let cardCornerRadius: CGFloat = 28
        static let searchToListSpacing: CGFloat = 16
        static let headerToSearchSpacing: CGFloat = 14
        static let searchBarHeight: CGFloat = 44
        static let cardMinHeight: CGFloat = 78
        static let cardHorizontalPadding: CGFloat = 18
        static let cardVerticalPadding: CGFloat = 12
        static let cardInnerSpacing: CGFloat = 10
        static let rowDividerSpacing: CGFloat = 12
        static let addButtonSize: CGFloat = 22
        static let waveformBarCount: Int = 16
        static let waveformLaneWidth: CGFloat = 70
        static let waveformLaneHeight: CGFloat = 14
    }

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                searchBar
                    .padding(.top, Layout.headerToSearchSpacing)
                recordingsList
                    .padding(.top, Layout.searchToListSpacing)
            }
            .padding(.horizontal, Layout.horizontalPadding)
            .padding(.top, 14)
        }
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
    }
}

// MARK: - UI

extension RecordingsPickerView {

    private var topBar: some View {
        HStack {
            closeButton

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

            Button {
                let selectedItems = recordings.filter { selectedRecordings.contains($0.id) }
                onSave(selectedItems)
                dismiss()
            } label: {
                Image(systemName: "checkmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color("MainPurple")))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
        }
    }

    /// Solid dark pill — matches Figma (not the glass search on Albums/Recordings pages).
    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color("tertiary"))

            TextField(
                "",
                text: $searchText,
                prompt: Text("Search").foregroundStyle(Color("tertiary"))
            )
            .foregroundStyle(.white)
            .autocorrectionDisabled()

            Spacer(minLength: 0)

            Image(systemName: "mic.fill")
                .foregroundStyle(Color("tertiary"))
        }
        .padding(.horizontal, 16)
        .frame(height: Layout.searchBarHeight)
        .background(
            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.12))
        )
    }

    private var closeButton: some View {
        Button(action: { dismiss() }) {
            Image(systemName: "xmark")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Color("SpaceBlue")))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private var recordingsList: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                ForEach(Array(filteredRecordings.enumerated()), id: \.element.id) { index, recording in
                    if index > 0 {
                        rowDivider
                    }
                    recordingRow(recording)
                }
            }
            .padding(.bottom, 20)
        }
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .frame(height: 1)
            .padding(.vertical, Layout.rowDividerSpacing)
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

    private func recordingRow(_ recording: RecordingItem) -> some View {
        let isSelected = selectedRecordings.contains(recording.id)

        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: Layout.cardInnerSpacing) {
                HStack(alignment: .firstTextBaseline) {
                    Text(recording.title)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    Text(recording.date)
                        .font(.system(size: 13))
                        .foregroundStyle(Color("tertiary"))
                }

                HStack(spacing: 8) {
                    WaveformBarsView(
                        barColor: .white.opacity(0.9),
                        heights: pickerWaveformHeights(for: recording),
                        maxBarHeight: 12,
                        barWidth: 2.5,
                        spacing: 2
                    )
                    .frame(
                        width: Layout.waveformLaneWidth,
                        height: Layout.waveformLaneHeight,
                        alignment: .leading
                    )

                    Text(recording.duration)
                        .font(.system(size: 13))
                        .foregroundStyle(Color("tertiary"))
                }
            }
            .padding(.horizontal, Layout.cardHorizontalPadding)
            .padding(.vertical, Layout.cardVerticalPadding)
            .frame(
                maxWidth: .infinity,
                minHeight: Layout.cardMinHeight,
                alignment: .leading
            )
            .background(
                RoundedRectangle(cornerRadius: Layout.cardCornerRadius, style: .continuous)
                    .fill(Color("SpaceBlue"))
            )

            Button {
                toggle(recording)
            } label: {
                ZStack {
                    Circle()
                        .stroke(Color("MainPurple"), lineWidth: 2)
                        .frame(width: Layout.addButtonSize, height: Layout.addButtonSize)

                    Image(systemName: isSelected ? "checkmark" : "plus")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color("MainPurple"))
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

    private func pickerWaveformHeights(for recording: RecordingItem) -> [CGFloat] {
        let base = recording.waveformHeights
        return (0..<Layout.waveformBarCount).map { base[$0 % base.count] }
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
