//
//  AlbumRecordingComponents.swift
//  Sensic
//

import SwiftUI

// MARK: - Swipe row (Rename · Move · Remove)

struct AlbumRecordingSwipeRow: View {
    let recording: RecordingItem
    @Binding var revealedRecordingID: UUID?
    var onRename: () -> Void = {}
    var onMove: () -> Void = {}
    var onRemove: () -> Void = {}
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
                    title: "Remove",
                    icon: "trash",
                    background: Color("RecordingRed"),
                    action: onRemove
                )
            }
            .frame(maxHeight: .infinity, alignment: .center)
            .allowsHitTesting(isRevealed)

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
        .frame(height: RecordingsPanelMetrics.rowHeight)
        .clipShape(RoundedRectangle(cornerRadius: RecordingsPanelMetrics.innerCornerRadius, style: .continuous))
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

struct AlbumRecordingCardView: View {
    let recording: RecordingItem

    var body: some View {
        RecordingItemCardContent(recording: recording)
            .padding(RecordingCardLayout.cardInsets)
            .frame(maxWidth: .infinity, minHeight: RecordingCardLayout.cardMinHeight, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: RecordingsPanelMetrics.innerCornerRadius, style: .continuous)
                    .fill(Color("SpaceBlue"))
            )
    }
}

