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
                    .foregroundStyle(SensicColors.secondaryText)
            }

            Spacer(minLength: 12)

            Button(action: onLibraryTap) {
                Image(systemName: "square.stack")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(SensicColors.accentPurple)
                    .frame(width: 44, height: 44)
                    .background(SensicColors.libraryButtonFill)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(SensicColors.cardBorder, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Piano card
// بطاقة الآلة (Piano) — التصميم من Figma: أيقونة يسار + نص وزر يمين

struct PianoInstrumentCard: View {
    var openCreation: () -> Void = {}

    /// نصف قطر زوايا البطاقة الخارجية
    private let cardCorner: CGFloat = 24

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            pianoIconCluster

            VStack(alignment: .center, spacing: 0) {
                Text("Piano")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)

                Text("Clear tactical pulses")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(Color(red: 168 / 255, green: 172 / 255, blue: 190 / 255))
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
        .contentShape(RoundedRectangle(cornerRadius: cardCorner, style: .continuous))
        .onTapGesture(perform: openCreation)
    }

//MARK: -Piaon Image section
    
    private var pianoIconCluster: some View {
        ZStack {
            // Blur Blue image
            Image("PianoGlowBlue")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 118, height: 118)
                .blendMode(.plusLighter)
                .allowsHitTesting(false)

            // Blur Purple image
            Image("PianoGlowPurple")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 90, height: 90)
                .blendMode(.plusLighter)
                .allowsHitTesting(false)

            // Piano Image
            Image("PianoInstrumentIcon")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .padding(.top,10)
                .frame(width: 70, height: 70)
        }
        .compositingGroup()
        .frame(width: 92, height: 92)
    }

//Background header card
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: cardCorner, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 14 / 255, green: 17 / 255, blue: 32 / 255),
                        Color(red: 22 / 255, green: 18 / 255, blue: 40 / 255),
                        Color(red: 28 / 255, green: 20 / 255, blue: 46 / 255),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
    }

//Border header card
    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: cardCorner, style: .continuous)
            .strokeBorder(
                LinearGradient(
                    colors: [
                        Color(red: 110 / 255, green: 80 / 255, blue: 160 / 255).opacity(0.45),
                        Color(red: 60 / 255, green: 45 / 255, blue: 100 / 255).opacity(0.2),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
    }
}

// Button
private struct GetStartedButton: View {
    let action: () -> Void

    var body: some View {
        Button("Get started", action: action)
            .font(.system(size: 15, weight: .semibold))
            .padding(.horizontal, 38)
             .padding(.vertical, 12)
             .controlSize(.regular)
             .buttonStyle(.glassProminent)
             .tint(SensicColors.accentPurpleButton)
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
                        .foregroundStyle(SensicColors.accentPurple)
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
            .background(Capsule().fill(background))
        }
        .buttonStyle(.plain)
    }
}

/// ارتفاع لوحة التسجيلات في الهوم — يتمدد لتحت فقط ولا يدفع الهيدر/البيانو لأعلى.
enum RecordingsPanelMetrics {
    static let contentHeight: CGFloat = 420
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

            RecordingRowView(piece: piece, isSelected: isRevealed)
                .frame(maxWidth: .infinity, alignment: .leading)
                .offset(x: rowOffset)
                .gesture(swipeGesture)
        }
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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
    let width: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(.white)
            .frame(width: width)
            .frame(maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(background)
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
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(red: 15 / 255, green: 15 / 255, blue: 28 / 255))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
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
