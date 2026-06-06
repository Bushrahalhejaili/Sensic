//
//  RecordingCardContent.swift
//  Sensic
//

import SwiftUI

// MARK: - Layout (Figma Group 339 — tight padding, album on bottom-right)

enum RecordingCardLayout {
    /// Figma Group 339 — symmetric insets.
    static let cardPaddingTop: CGFloat = 18
    static let cardPaddingHorizontal: CGFloat = 18
    static let cardPaddingBottom: CGFloat = 18
    static let rowSpacing: CGFloat = 10
    static let cardMinHeight: CGFloat = 78
    static let waveformLaneHeight: CGFloat = 16
    static let waveformBarMaxHeight: CGFloat = 12
    static let albumBadgeRowHeight: CGFloat = 16

    static var cardInsets: EdgeInsets {
        EdgeInsets(
            top: cardPaddingTop,
            leading: cardPaddingHorizontal,
            bottom: cardPaddingBottom,
            trailing: cardPaddingHorizontal
        )
    }
}

// MARK: - Album badge

struct RecordingAlbumBadge: View {
    let albumName: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "folder")
                .font(.system(size: 11, weight: .semibold))
            Text(albumName)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
        }
        .foregroundStyle(Color("tertiary"))
    }
}

// MARK: - Shared row body (Home + Recordings)

struct RecordingPieceCardContent: View {
    let piece: Piece
    var primaryAlbumName: String?

    var body: some View {
        VStack(alignment: .leading, spacing: RecordingCardLayout.rowSpacing) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(piece.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Spacer(minLength: 8)

                Text(piece.listDateLabel())
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Color("tertiary"))
            }

            HStack(alignment: .center, spacing: 6) {
                WaveformBarsView(
                    barColor: .white.opacity(0.85),
                    heights: piece.waveformHeights,
                    maxBarHeight: RecordingCardLayout.waveformBarMaxHeight
                )
                .frame(height: RecordingCardLayout.waveformLaneHeight)
                .id(piece.id)

                Text(piece.formattedDuration)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Color("tertiary"))

                Spacer(minLength: 8)

                bottomTrailingAlbum
            }
        }
    }

    @ViewBuilder
    private var bottomTrailingAlbum: some View {
        ZStack(alignment: .trailing) {
            if let primaryAlbumName {
                RecordingAlbumBadge(albumName: primaryAlbumName)
            }
        }
        .frame(height: RecordingCardLayout.albumBadgeRowHeight, alignment: .trailing)
    }
}

// MARK: - Album detail row body (same layout as Home + Recordings)

struct RecordingItemCardContent: View {
    let recording: RecordingItem

    var body: some View {
        VStack(alignment: .leading, spacing: RecordingCardLayout.rowSpacing) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(recording.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Spacer(minLength: 8)

                Text(recording.date)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Color("tertiary"))
            }

            HStack(alignment: .center, spacing: 6) {
                WaveformBarsView(
                    barColor: .white.opacity(0.85),
                    heights: recording.waveformHeights,
                    maxBarHeight: RecordingCardLayout.waveformBarMaxHeight
                )
                .frame(height: RecordingCardLayout.waveformLaneHeight)
                .id(recording.id)

                Text(recording.duration)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Color("tertiary"))

                Spacer(minLength: 8)
            }
        }
    }
}

extension RecordingItem {
    var waveformHeights: [CGFloat] {
        let bytes = withUnsafeBytes(of: id.uuid) { Array($0) }
        let count = 10
        return (0..<count).map { index in
            let a = bytes[index % bytes.count]
            let b = bytes[(index + 7) % bytes.count]
            let mixed = (UInt16(a) + UInt16(b)) % 256
            return CGFloat(0.28 + Double(mixed) / 255.0 * 0.67)
        }
    }
}
