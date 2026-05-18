//
//  PracticeNoteVisualizer.swift
//  Sensic
//

import SwiftUI

// MARK: - Blue gradient palette (light = soft/sharp, dark = heavy)

private enum PracticeBlueGradient {
    private static let lightRGB = (0.549, 0.824, 1.0)
    private static let darkRGB = (0.0, 0.306, 0.745)

    /// Soft touch → lighter blue; heavy touch → darker blue, with a subtle vertical gradient in the column.
    static func dotColor(velocity: UInt8, rowInFill: Int, fillCount: Int) -> Color {
        let weight = min(1, max(0, Double(velocity - 48) / 79))
        let base = blendRGB(lightRGB, darkRGB, weight)

        guard fillCount > 1 else {
            return color(base)
        }

        let rowWeight = Double(rowInFill) / Double(fillCount - 1)
        let shaded = blendRGB(base, darkRGB, rowWeight * 0.45)
        return color(shaded)
    }

    private static func blendRGB(
        _ from: (Double, Double, Double),
        _ to: (Double, Double, Double),
        _ amount: Double
    ) -> (Double, Double, Double) {
        let t = min(1, max(0, amount))
        return (
            from.0 + (to.0 - from.0) * t,
            from.1 + (to.1 - from.1) * t,
            from.2 + (to.2 - from.2) * t
        )
    }

    private static func color(_ rgb: (Double, Double, Double)) -> Color {
        Color(red: rgb.0, green: rgb.1, blue: rgb.2)
    }
}

struct PracticeNoteVisualizerGrid: View {
    @ObservedObject var model: PracticeVisualizerModel

    private let columns = PracticeVisualizerModel.columnCount
    private let rows = PracticeVisualizerModel.rowCount
    private let cardInset: CGFloat = 16

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(SensicColors.panelNavy)

            GeometryReader { geo in
                let metrics = GridMetrics.fit(
                    columns: columns,
                    rows: rows,
                    in: CGSize(
                        width: max(0, geo.size.width - cardInset * 2),
                        height: max(0, geo.size.height - cardInset * 2)
                    )
                )

                HStack(alignment: .bottom, spacing: metrics.columnGap) {
                    ForEach(0..<columns, id: \.self) { column in
                        columnView(
                            activeCount: model.columnFills[column] ?? 0,
                            velocity: model.columnVelocities[column] ?? 88,
                            metrics: metrics
                        )
                    }
                }
                .frame(width: metrics.totalWidth, height: metrics.totalHeight)
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
        )
    }

    private func columnView(activeCount: Int, velocity: UInt8, metrics: GridMetrics) -> some View {
        VStack(spacing: metrics.rowGap) {
            ForEach(0..<rows, id: \.self) { row in
                dotView(
                    row: row,
                    activeCount: activeCount,
                    velocity: velocity,
                    dotSize: metrics.dotSize
                )
            }
        }
        .frame(width: metrics.columnWidth, height: metrics.totalHeight, alignment: .bottom)
        .animation(.easeOut(duration: 0.12), value: activeCount)
        .animation(.easeOut(duration: 0.12), value: velocity)
    }

    private func dotView(row: Int, activeCount: Int, velocity: UInt8, dotSize: CGFloat) -> some View {
        let activeStartRow = rows - activeCount

        return ZStack {
            Circle()
                .fill(Color.white.opacity(0.38))
                .frame(width: dotSize, height: dotSize)

            if activeCount > 0, row >= activeStartRow {
                let rowInFill = row - activeStartRow
                Circle()
                    .fill(
                        PracticeBlueGradient.dotColor(
                            velocity: velocity,
                            rowInFill: rowInFill,
                            fillCount: activeCount
                        )
                    )
                    .frame(width: dotSize, height: dotSize)
            }
        }
        .frame(width: dotSize, height: dotSize)
    }
}

private struct GridMetrics {
    let dotSize: CGFloat
    let columnGap: CGFloat
    let rowGap: CGFloat
    let columnWidth: CGFloat
    let totalWidth: CGFloat
    let totalHeight: CGFloat

    static func fit(columns: Int, rows: Int, in available: CGSize) -> GridMetrics {
        let maxColumnGap: CGFloat = 6
        let maxRowGap: CGFloat = 6
        let maxDot: CGFloat = 10

        guard available.width > 0, available.height > 0, columns > 0, rows > 0 else {
            return GridMetrics(
                dotSize: 1,
                columnGap: 0,
                rowGap: 0,
                columnWidth: 1,
                totalWidth: 1,
                totalHeight: 1
            )
        }

        let widthForDots = (available.width - CGFloat(columns - 1) * maxColumnGap) / CGFloat(columns)
        let heightForDots = (available.height - CGFloat(rows - 1) * maxRowGap) / CGFloat(rows)
        let dotSize = min(maxDot, widthForDots, heightForDots)

        let columnGap = columns > 1
            ? min(maxColumnGap, (available.width - CGFloat(columns) * dotSize) / CGFloat(columns - 1))
            : 0
        let rowGap = rows > 1
            ? min(maxRowGap, (available.height - CGFloat(rows) * dotSize) / CGFloat(rows - 1))
            : 0

        let totalWidth = CGFloat(columns) * dotSize + CGFloat(columns - 1) * columnGap
        let totalHeight = CGFloat(rows) * dotSize + CGFloat(rows - 1) * rowGap

        return GridMetrics(
            dotSize: dotSize,
            columnGap: columnGap,
            rowGap: rowGap,
            columnWidth: dotSize,
            totalWidth: totalWidth,
            totalHeight: totalHeight
        )
    }
}
