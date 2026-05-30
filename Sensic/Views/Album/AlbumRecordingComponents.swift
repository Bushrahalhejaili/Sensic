//
//  AlbumRecordingComponents.swift
//  Sensic
//

import SwiftUI

// MARK: - Swipe row (Rename · Move · Delete)

struct AlbumRecordingSwipeRow: View {
    let recording: RecordingItem
    @Binding var revealedRecordingID: UUID?
    var onRename: () -> Void = {}
    var onMove: () -> Void = {}
    var onDelete: () -> Void = {}
    var onDetail: () -> Void = {}

    private var actionsRevealWidth: CGFloat { RecordingSwipeActionMetrics.totalRevealWidth }
    private var actionSpacing: CGFloat { RecordingSwipeActionMetrics.spacing }

    @State private var dragOffset: CGFloat = 0
    @State private var isDraggingHorizontally = false

    private var isRevealed: Bool { revealedRecordingID == recording.id }

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
                    title: "Move",
                    icon: "folder",
                    background: Color("MainPurple"),
                    action: onMove
                )
                RecordingSwipeAction(
                    title: "Delete",
                    icon: "trash",
                    background: Color("RecordingRed"),
                    action: onDelete
                )
            }
            .frame(maxHeight: .infinity, alignment: .center)

            AlbumRecordingCardView(recording: recording)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .offset(x: rowOffset)
                .gesture(swipeGesture)
                .onTapGesture {
                    if isRevealed {
                        revealedRecordingID = nil
                    } else {
                        onDetail()
                    }
                }
        }
        .frame(maxWidth: .infinity)
        .frame(height: AlbumRecordingMetrics.rowHeight)
        .clipShape(RoundedRectangle(cornerRadius: AlbumRecordingMetrics.cornerRadius, style: .continuous))
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
                    if let openID = revealedRecordingID, openID != recording.id {
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
                        revealedRecordingID = recording.id
                    } else if revealedRecordingID == recording.id {
                        revealedRecordingID = nil
                    }
                }
            }
    }
}

// MARK: - Card

private enum AlbumRecordingMetrics {
    static let cornerRadius: CGFloat = 30
    static let rowHeight: CGFloat = 105
}

struct AlbumRecordingCardView: View {
    let recording: RecordingItem

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(recording.title)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Spacer(minLength: 8)

                Text(recording.date)
                    .font(.system(size: 14))
                    .foregroundStyle(.gray)
            }

            HStack(spacing: 10) {
                Image(systemName: "waveform")
                    .foregroundStyle(.white)

                Text(recording.duration)
                    .foregroundStyle(.gray)
            }
        }
        .padding(.horizontal, 22)
        .frame(maxWidth: .infinity, minHeight: AlbumRecordingMetrics.rowHeight, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AlbumRecordingMetrics.cornerRadius, style: .continuous)
                .fill(
                    Color(
                        red: 16 / 255,
                        green: 22 / 255,
                        blue: 58 / 255
                    )
                )
        )
    }
}



