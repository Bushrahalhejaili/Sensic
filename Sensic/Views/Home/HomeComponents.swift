//
//  HomeComponents.swift
//  Sensic
//


import SwiftUI

// MARK: - Layout (shared horizontal margins & card rhythm)

enum HomeLayout {
    static let horizontalPadding: CGFloat = 20
    static let sectionSpacing: CGFloat = 28
    static let subsectionSpacing: CGFloat = 14
    static let cardCornerRadius: CGFloat = 16
    static let cardInnerCornerRadius: CGFloat = 12
}

// MARK: - Header

struct HomeHeaderView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Welcome")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(.white)

            Text("Choose an instrument to start")
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(Color("tertiary"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct HomeAlbumLibraryButton: View {
    var onTap: () -> Void = {}

    var body: some View {
        SensicGlassCircleButton(systemName: "square.stack", action: onTap)
    }
}

// MARK: - Piano card

struct PianoInstrumentCard: View {
    var openCreation: () -> Void = {}

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            pianoIconCluster

            VStack(alignment: .center, spacing: 0) {
                Text("Piano")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)

                Text("Clear tactical pulses")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(Color("tertiary"))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 4)

                GetStartedButton(action: openCreation)
                    .padding(.top, 14)
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .frame(height: 172)
        .background(cardBackground)
        .overlay(cardBorder)
        .clipShape(RoundedRectangle(cornerRadius: HomeLayout.cardCornerRadius, style: .continuous))
    }

//MARK: -Piaon Image section

    private var pianoIconCluster: some View {
        ZStack {
            Image("PianoGlowBlue")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 141, height: 137)
                .blendMode(.plusLighter)
                .allowsHitTesting(false)

            Image("PianoGlowPurple")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 105, height: 93)
                .blendMode(.plusLighter)
                .allowsHitTesting(false)

            Image("PianoInstrumentIcon")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .padding(.top, 10)
                .frame(width: 95, height: 80)
        }
        .compositingGroup()
        .frame(width: 92, height: 92)
        .padding(.horizontal, 20)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: HomeLayout.cardCornerRadius, style: .continuous)
            .fill(Color("Navy"))
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: HomeLayout.cardCornerRadius, style: .continuous)
            .strokeBorder(
                LinearGradient(
                    colors: [
                        Color("MainPurple"),
                        Color("Lavender"),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
    }
}

// Button — Figma: 165×36, glass + MainPurple
private struct GetStartedButton: View {
    let action: () -> Void

    private let width: CGFloat = 165
    private let height: CGFloat = 36

    var body: some View {
        Button(action: action) {
            Text("Get started")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: width, height: height)
        }
        .buttonStyle(.plain)
        .background { buttonChrome }
        .frame(width: width, height: height)
        .clipShape(Capsule(style: .continuous))
        .contentShape(Capsule(style: .continuous))
        .padding(.top,16)
        .padding(.bottom,6)

    }

    private var buttonChrome: some View {
        Capsule(style: .continuous)
            .fill(Color("MainPurple"))
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.5),
                                Color.white.opacity(0.15),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            }
            .glassEffect(in: .capsule)
    }
}

// MARK: - Recordings

struct RecordingsSectionHeader: View {
    var showsSeeAll: Bool = true
    var onSeeAll: () -> Void = {}

    var body: some View {
        HStack {
            Text("Recordings")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)

            Spacer()

            if showsSeeAll {
                Button(action: onSeeAll) {
                    Text("See all")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color("MainPurple"))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct RecordingActionBar: View {
    var onRename: () -> Void = {}
    var onAdd: () -> Void = {}
    var onDelete: () -> Void = {}

    var body: some View {
        HStack(spacing: 10) {
            RecordingActionButton(
                title: "Rename",
                icon: "pencil",
                background: Color("IndigoBlue"),
                action: onRename
            )
            RecordingActionButton(
                title: "Add",
                icon: "folder.badge.plus",
                background: Color("Lavender"),
                action: onAdd
            )
            RecordingActionButton(
                title: "Delete",
                icon: "trash",
                background: Color("RecordingRed"),
                action: onDelete
            )
        }
    }
}

private struct RecordingActionButton: View {
    let title: String
    let icon: String
    let background: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Capsule().fill(Color("SpaceBlue")))
        }
        .buttonStyle(.plain)
    }
}

enum RecordingsPanelMetrics {
    static let cornerRadius: CGFloat = 20
    static let innerCornerRadius: CGFloat = 20
    static let rowHeight: CGFloat = RecordingCardLayout.cardMinHeight
    static let rowSpacing: CGFloat = 9
    static let panelInset: CGFloat = 14

    static func panelHeight(rowCount: Int, isEmpty: Bool) -> CGFloat {
        if isEmpty { return 200 }
        let rows = max(1, rowCount)
        return CGFloat(rows) * rowHeight
            + CGFloat(max(0, rows - 1)) * rowSpacing
            + panelInset * 2
    }
}

enum RecordingSwipeActionMetrics {
    static let width: CGFloat = 92
    static let height: CGFloat = 44
    static let spacing: CGFloat = 8
    /// Gap between recording card trailing edge and first action when revealed.
    static let cardToActionsGap: CGFloat = 5
    static var totalRevealWidth: CGFloat { cardToActionsGap + width * 3 + spacing * 2 }
}

struct RecordingsEmptyState: View {
    var body: some View {
        VStack(spacing: 12) {
            WaveformBarsView(
                barColor: Color("tertiary").opacity(0.7),
                heights: WaveformBarsView.emptyPlaceholderHeights,
                barWidth: 4,
                spacing: 5
            )
                .frame(height: 32)

            Text("No pieces yet")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Color("tertiary"))

            Text("Start to create one")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(Color("tertiary").opacity(0.85))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}

struct SwipeableRecordingRow: View {
    let piece: Piece
    var primaryAlbumName: String?
    @Binding var revealedRecordingID: UUID?
    var onOpen: () -> Void = {}
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

            RecordingRowView(piece: piece, primaryAlbumName: primaryAlbumName)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .offset(x: rowOffset)
                .contentShape(Rectangle())
                // Tap to reopen the recording in the editor.  If the
                // swipe actions are revealed, the tap closes them
                // first (matching the iOS Mail / Messages pattern)
                // instead of opening — feels less surprising than
                // navigating away from a half-completed gesture.
                .onTapGesture {
                    if isRevealed {
                        revealedRecordingID = nil
                    } else {
                        onOpen()
                    }
                }
                .gesture(swipeGesture)
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

struct RecordingSwipeAction: View {

    let title: String
    let icon: String
    let background: Color
    let action: () -> Void

    var body: some View {

        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 16)
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .foregroundStyle(.white)
            .frame(
                width: RecordingSwipeActionMetrics.width,
                height: RecordingSwipeActionMetrics.height,
                alignment: .center
            )
            .background(background, in: Capsule(style: .continuous))
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct RecordingRowView: View {
    let piece: Piece
    var primaryAlbumName: String?

    var body: some View {
        RecordingPieceCardContent(piece: piece, primaryAlbumName: primaryAlbumName)
            .padding(RecordingCardLayout.cardInsets)
            .frame(maxWidth: .infinity, minHeight: RecordingCardLayout.cardMinHeight, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: RecordingsPanelMetrics.innerCornerRadius, style: .continuous)
                    .fill(Color("SpaceBlue"))
            )
    }
}

struct WaveformBarsView: View {
    static let emptyPlaceholderHeights: [CGFloat] = [0.35, 0.55, 0.75, 0.45, 0.6]

    let barColor: Color
    let heights: [CGFloat]
    var maxBarHeight: CGFloat = 18
    var barWidth: CGFloat = 2.5
    var spacing: CGFloat = 2

    var body: some View {
        HStack(alignment: .center, spacing: spacing) {
            ForEach(Array(heights.enumerated()), id: \.offset) { _, height in
                Capsule()
                    .fill(barColor)
                    .frame(width: barWidth, height: max(2, maxBarHeight * height))
            }
        }
    }
}
