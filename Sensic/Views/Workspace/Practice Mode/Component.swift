//
//  Component.swift
//  Sensic
//


import SwiftUI

// MARK: - GridMetrics

struct GridMetrics {
    let dotSize: CGFloat
    let columnGap: CGFloat
    let rowGap: CGFloat
    let columnWidth: CGFloat
    let totalWidth: CGFloat
    let totalHeight: CGFloat

    static func fit(columns: Int, rows: Int, in available: CGSize) -> GridMetrics {
        guard available.width > 0, available.height > 0, columns > 0, rows > 0 else {
            return GridMetrics(dotSize: 2, columnGap: 0, rowGap: 0,
                               columnWidth: 1, totalWidth: 1, totalHeight: 1)
        }

        let colGap: CGFloat = 5
        let rowGap: CGFloat = 5
        // بدون maxDot — الدائرة تتحدد حسب المساحة الكاملة
        let dotW = (available.width  - CGFloat(columns - 1) * colGap) / CGFloat(columns)
        let dotH = (available.height - CGFloat(rows - 1)    * rowGap) / CGFloat(rows)
        let dotSize = min(dotW, dotH)

        return GridMetrics(
            dotSize:     dotSize,
            columnGap:   colGap,
            rowGap:      rowGap,
            columnWidth: dotSize,
            totalWidth:  CGFloat(columns) * dotSize + CGFloat(columns - 1) * colGap,
            totalHeight: CGFloat(rows)    * dotSize + CGFloat(rows - 1)    * rowGap
        )
    }
}
