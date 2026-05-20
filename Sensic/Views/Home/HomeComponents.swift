//
//  HomeComponents.swift
//  Sensic
//

import SwiftUI

// MARK: - Header

struct HomeHeaderView: View {
    var onLibraryTap: () -> Void = {}

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Welcome")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.white)

                Text("Choose an instrument to start")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(Color("tertiary"))
            }

            Spacer(minLength: 12)

            Button(action: onLibraryTap) {
                Image(systemName: "square.stack")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color("MainPurple"))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .background { libraryGlassChrome }
            .clipShape(Circle())
            .contentShape(Circle())
        }
    }

    private var libraryGlassChrome: some View {
        Circle()
            .fill(Color("Navy"))
            .overlay {
                Circle()
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.35),
                                Color.white.opacity(0.1),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            }
            .glassEffect(in: .circle)
    }
}

// MARK: - Piano card

struct PianoInstrumentCard: View {
    var openCreation: () -> Void = {}

    /// نصف قطر زوايا البطاقة الخارجية
    private let cardCorner: CGFloat = 10

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
        .background(cardBackground)
        .overlay(cardBorder)
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

//Background header card
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: cardCorner, style: .continuous)
            .fill( Color("Navy") )
            .frame(width: 370, height: 172)
    }

//Border header card
    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: cardCorner, style: .continuous)
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
                background: SensicColors.accentBlue,
                action: onRename
            )
            RecordingActionButton(
                title: "Add",
                icon: "folder.badge.plus",
                background: SensicColors.accentPurpleButton,
                action: onAdd
            )
            RecordingActionButton(
                title: "Delete",
                icon: "trash",
                background: SensicColors.accentRed,
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
    static let contentHeight: CGFloat = 420
    static let cornerRadius: CGFloat = 20
}

enum RecordingSwipeActionMetrics {
    static let width: CGFloat = 92
    static let height: CGFloat = 44
    static let spacing: CGFloat = 8
    static var totalRevealWidth: CGFloat { width * 3 + spacing * 2 }
}

struct RecordingsEmptyState: View {
    var body: some View {
        VStack(spacing: 12) {
            WaveformBarsView(
                barColor: SensicColors.secondaryText.opacity(0.7),
                heights: WaveformBarsView.emptyPlaceholderHeights,
                barWidth: 4,
                spacing: 5
            )
                .frame(height: 32)

            Text("No pieces yet")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(SensicColors.secondaryText)

            Text("Start to create one")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(SensicColors.secondaryText.opacity(0.85))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}

struct SwipeableRecordingRow: View {
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
        ZStack(alignment: .trailing) {
            HStack(spacing: actionSpacing) {
                RecordingSwipeAction(
                    title: "Rename",
                    icon: "pencil",
                    background: SensicColors.indigo,
                    action: onRename
                )
                RecordingSwipeAction(
                    title: "Add",
                    icon: "folder",
                    background: SensicColors.mainPurple,
                    action: onAdd
                )
                RecordingSwipeAction(
                    title: "Delete",
                    icon: "trash",
                    background: SensicColors.recordingRed,
                    action: onDelete
                )
            }

            RecordingRowView(piece: piece, isSelected: isRevealed)
                .frame(maxWidth: .infinity, alignment: .leading)
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
    var isSelected: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(piece.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Spacer(minLength: 8)

                Text(piece.relativeTimestamp)
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
            RoundedRectangle(cornerRadius: RecordingsPanelMetrics.cornerRadius, style: .continuous)
                .fill(SensicColors.recordingCardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: RecordingsPanelMetrics.cornerRadius, style: .continuous)
                .stroke(isSelected ? SensicColors.accentPurple.opacity(0.5) : .clear, lineWidth: 1)
        )
    }
}

struct WaveformBarsView: View {
    static let emptyPlaceholderHeights: [CGFloat] = [0.35, 0.55, 0.75, 0.45, 0.6]

    let barColor: Color
    let heights: [CGFloat]
    var barWidth: CGFloat = 2.5
    var spacing: CGFloat = 2

    var body: some View {
        HStack(alignment: .center, spacing: spacing) {
            ForEach(Array(heights.enumerated()), id: \.offset) { _, height in
                Capsule()
                    .fill(barColor)
                    .frame(width: barWidth, height: 28 * height)
            }
        }
    }
}
