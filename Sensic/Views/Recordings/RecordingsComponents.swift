//
//  RecordingsComponents.swift
//  Sensic
//

import SwiftUI

// MARK: - Header

struct RecordingsHeaderView: View {
    let count: Int
    /// When true, title sits in one row with the back button (after scrolling).
    var collapsed: Bool = false
    var onBack: () -> Void = {}

    private let backButtonSize: CGFloat = 44
    /// Collapsed: centered title + count (iOS large-title collapse style).
    private let collapsedHeaderHeight: CGFloat = 56

    var body: some View {
        Group {
            if collapsed {
                ZStack {
                    HStack {
                        backButton
                        Spacer(minLength: 0)
                    }
                    VStack(spacing: 2) {
                        Text("Recordings")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text("\(count) Recordings")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(Color("tertiary"))
                            .lineLimit(1)
                    }
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .frame(maxWidth: .infinity)
                .frame(height: collapsedHeaderHeight)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .center, spacing: 0) {
                        backButton
                        Spacer(minLength: 0)
                    }

                    Text("Recordings")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(.white)

                    Text("\(count) Recordings")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(Color("tertiary"))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: collapsed)
    }

    private var backButton: some View {
        Button(action: onBack) {
            Image(systemName: "chevron.left")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: backButtonSize, height: backButtonSize)
                .background(Color("Navy"))
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color("MainPurple").opacity(0.35), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
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
                RoundedRectangle(cornerRadius: RecordingsPanelMetrics.cornerRadius, style: .continuous)
                    .fill(Color("SpaceBlue").opacity(0.5))
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

    private var actionsRevealWidth: CGFloat { RecordingSwipeActionMetrics.totalRevealWidth }
    private var actionSpacing: CGFloat { RecordingSwipeActionMetrics.spacing }

    @State private var dragOffset: CGFloat = 0
    @State private var isDraggingHorizontally = false

    private var isRevealed: Bool { revealedRecordingID == piece.id }

    private var rowOffset: CGFloat {
        let settled = isRevealed ? -actionsRevealWidth : 0
        return min(0, max(-actionsRevealWidth, settled + dragOffset))
    }

    var body: some View {
        ZStack(alignment: Alignment(horizontal: .trailing, vertical: .center)) {
            HStack(spacing: actionSpacing) {
                Color.clear.frame(width: RecordingSwipeActionMetrics.cardToActionsGap)
                RecordingSwipeAction(
                    title: "Rename",
                    icon: "pencil",
                    background: Color("IndigoBlue"),
                    action: onRename
                )
                RecordingSwipeAction(
                    title: "Add",
                    icon: "folder",
                    background: Color("MainPurple"),
                    action: onAdd
                )
                RecordingSwipeAction(
                    title: "Delete",
                    icon: "trash",
                    background: Color("RecordingRed"),
                    action: onDelete
                )
            }
            .frame(maxHeight: .infinity, alignment: .center)

            RecordingsCardView(piece: piece)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .offset(x: rowOffset)
                .gesture(swipeGesture)
        }
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: RecordingsPanelMetrics.cornerRadius, style: .continuous))
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
                    .foregroundStyle(Color("tertiary"))
            }

            HStack(spacing: 8) {
                WaveformBarsView(barColor: .white.opacity(0.85), heights: piece.waveformHeights)
                    .frame(height: 18)
                    .id(piece.id)

                Text(piece.formattedDuration)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Color("tertiary"))
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: RecordingsPanelMetrics.cornerRadius, style: .continuous)
                .fill(Color("SpaceBlue"))
        )
    }
}

// MARK: - Search

struct RecordingsSearchBar: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color("tertiary"))

            TextField("Search", text: $text)
                .foregroundStyle(.white)
                .autocorrectionDisabled()

            Image(systemName: "mic.fill")
                .foregroundStyle(Color("tertiary"))
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
                barColor: Color("tertiary").opacity(0.7),
                heights: WaveformBarsView.emptyPlaceholderHeights,
                barWidth: 4,
                spacing: 5
            )
            .frame(height: 32)

            Text("No recordings yet")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Color("tertiary"))
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
            .background(Capsule().fill(Color("Lavender")))
            .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
    }
}
