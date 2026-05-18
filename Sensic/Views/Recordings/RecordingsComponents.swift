//
//  RecordingsComponents.swift
//  Sensic
//

import SwiftUI

// MARK: - Header

struct RecordingsHeaderView: View {
    let count: Int
    var onBack: () -> Void = {}

    private let backButtonSize: CGFloat = 44

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 12) {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: backButtonSize, height: backButtonSize)
                        .background(SensicColors.libraryButtonFill)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(SensicColors.cardBorder, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)

                Text("Recordings")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.white)

                Spacer(minLength: 0)
            }

            Text("\(count) Recordings")
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(SensicColors.secondaryText)
                .padding(.leading, backButtonSize + 12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Section

struct RecordingsSectionView: View {
    let section: RecordingSection
    @Binding var revealedRecordingID: UUID?
    var onRename: (Piece) -> Void
    var onAdd: (Piece) -> Void
    var onDelete: (Piece) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(section.title)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)

            VStack(spacing: 4) {
                ForEach(section.pieces) { piece in
                    RecordingsSwipeRow(
                        piece: piece,
                        revealedRecordingID: $revealedRecordingID,
                        onRename: { onRename(piece) },
                        onAdd: { onAdd(piece) },
                        onDelete: { onDelete(piece) }
                    )
                }
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(SensicColors.panelNavy)
            )
        }
    }
}

// MARK: - Swipe row (same as Home — actions reveal on the right)

struct RecordingsSwipeRow: View {
    let piece: Piece
    @Binding var revealedRecordingID: UUID?
    var onRename: () -> Void = {}
    var onAdd: () -> Void = {}
    var onDelete: () -> Void = {}

    private let actionWidth: CGFloat = 56
    private let actionSpacing: CGFloat = 6
    private var actionsRevealWidth: CGFloat { actionWidth * 3 + actionSpacing * 2 }

    @State private var dragOffset: CGFloat = 0
    @State private var isDraggingHorizontally = false

    private var isRevealed: Bool { revealedRecordingID == piece.id }

    private var rowOffset: CGFloat {
        let settled = isRevealed ? -actionsRevealWidth : 0
        return min(0, max(-actionsRevealWidth, settled + dragOffset))
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            HStack(spacing: actionSpacing) {
                RecordingSwipeAction(
                    title: "Rename",
                    icon: "pencil",
                    background: SensicColors.accentBlue,
                    width: actionWidth,
                    action: onRename
                )
                RecordingSwipeAction(
                    title: "Add",
                    icon: "folder",
                    background: SensicColors.accentPurpleButton,
                    width: actionWidth,
                    action: onAdd
                )
                RecordingSwipeAction(
                    title: "Delete",
                    icon: "trash",
                    background: SensicColors.accentRed,
                    width: actionWidth,
                    action: onDelete
                )
            }

            RecordingsCardView(piece: piece, isSelected: isRevealed)
                .frame(maxWidth: .infinity, alignment: .leading)
                .offset(x: rowOffset)
                .gesture(swipeGesture)
        }
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: isRevealed)
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: dragOffset)
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 12, coordinateSpace: .local)
            .onChanged { value in
                let horizontal = abs(value.translation.width)
                let vertical = abs(value.translation.height)

                if !isDraggingHorizontally {
                    guard horizontal > vertical else { return }
                    isDraggingHorizontally = true
                    if let openID = revealedRecordingID, openID != piece.id {
                        revealedRecordingID = nil
                    }
                }

                dragOffset = value.translation.width
            }
            .onEnded { value in
                defer {
                    isDraggingHorizontally = false
                    dragOffset = 0
                }

                guard isDraggingHorizontally else { return }

                let settled = isRevealed ? -actionsRevealWidth : 0
                let projected = settled + value.translation.width

                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                    if projected < -actionsRevealWidth / 2 {
                        revealedRecordingID = piece.id
                    } else if revealedRecordingID == piece.id {
                        revealedRecordingID = nil
                    }
                }
            }
    }
}

struct RecordingsCardView: View {
    let piece: Piece
    var isSelected: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(piece.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Spacer(minLength: 8)

                Text(piece.listDateLabel())
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(SensicColors.secondaryText)
            }

            HStack(spacing: 8) {
                WaveformBarsView(barColor: .white.opacity(0.85), heights: piece.waveformHeights)
                    .frame(height: 18)
                    .id(piece.id)

                Text(piece.formattedDuration)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(SensicColors.secondaryText)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(red: 15 / 255, green: 15 / 255, blue: 28 / 255))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isSelected ? SensicColors.accentPurple.opacity(0.5) : .clear, lineWidth: 1)
        )
    }
}

// MARK: - Search

struct RecordingsSearchBar: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(SensicColors.secondaryText)

            TextField("Search", text: $text)
                .foregroundStyle(.white)
                .autocorrectionDisabled()

            Image(systemName: "mic.fill")
                .foregroundStyle(SensicColors.secondaryText)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .glassEffect(in: .rect(cornerRadius: 16))
    }
}

struct RecordingsEmptyListState: View {
    var body: some View {
        VStack(spacing: 12) {
            WaveformBarsView(
                barColor: SensicColors.secondaryText.opacity(0.7),
                heights: WaveformBarsView.emptyPlaceholderHeights,
                barWidth: 4,
                spacing: 5
            )
            .frame(height: 32)

            Text("No recordings yet")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(SensicColors.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }
}

struct RecordingsToastView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Capsule().fill(SensicColors.accentPurpleButton))
            .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
    }
}
