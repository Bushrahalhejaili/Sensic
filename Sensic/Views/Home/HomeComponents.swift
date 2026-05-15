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
                Image(systemName: "square.stack.3d.up.fill")
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
    var onGetStarted: () -> Void = {}

    /// نصف قطر زوايا البطاقة الخارجية
    private let cardCorner: CGFloat = 24

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            pianoIconCluster

            VStack(alignment: .leading, spacing: 0) {
                Text("Piano")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.white)

                Text("Clear tactical pulses")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(Color(red: 168 / 255, green: 172 / 255, blue: 190 / 255))
                    .padding(.top, 4)

                GetStartedButton(action: onGetStarted)
                    .padding(.top, 14)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(cardBackground)
        .overlay(cardBorder)
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

/// ارتفاع ثابت لمحتوى بطاقة التسجيلات (فارغة أو فيها قائمة)
enum RecordingsPanelMetrics {
    static let contentHeight: CGFloat = 250
}

struct RecordingsEmptyState: View {
    var body: some View {
        VStack(spacing: 12) {
            WaveformBarsView(barColor: SensicColors.secondaryText.opacity(0.7), style: .empty)
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
                WaveformBarsView(barColor: .white.opacity(0.85), style: .compact)
                    .frame(height: 18)

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
    enum Style {
        case empty
        case compact
    }

    let barColor: Color
    var style: Style = .compact

    private var heights: [CGFloat] {
        switch style {
        case .empty:
            [0.35, 0.55, 0.75, 0.45, 0.6]
        case .compact:
            [0.4, 0.65, 0.5, 0.8, 0.55, 0.7, 0.45, 0.6, 0.75, 0.5, 0.65, 0.4]
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: style == .empty ? 5 : 2) {
            ForEach(Array(heights.enumerated()), id: \.offset) { _, height in
                Capsule()
                    .fill(barColor)
                    .frame(width: style == .empty ? 4 : 2.5, height: 28 * height)
            }
        }
    }
}
