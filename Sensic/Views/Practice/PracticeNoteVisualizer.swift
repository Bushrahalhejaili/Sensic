//
//  PracticeVisualizerShapes.swift
//  Sensic
//

import SwiftUI

// MARK: - 1. Dots Grid

struct DotsGridVisualizer: View {
    @ObservedObject var model: PracticeVisualizerModel

    private let columns = PracticeVisualizerModel.columnCount
    private let rows    = PracticeVisualizerModel.rowCount
    private let inset: CGFloat = 8

    private static let columnHeights = [7, 7, 8, 8, 7, 7, 8, 9, 8, 8, 7, 7, 7, 8, 8, 7, 7]

    private func columnRows(_ col: Int) -> Int {
        guard col < Self.columnHeights.count else { return 3 }
        return Self.columnHeights[col]
    }

    var body: some View {
        GeometryReader { geo in
            let metrics = GridMetrics.fit(
                columns: columns, rows: rows,
                in: CGSize(width:  max(0, geo.size.width  - inset * 2),
                           height: max(0, geo.size.height - inset * 2))
            )
            HStack(alignment: .bottom, spacing: metrics.columnGap) {
                ForEach(0..<columns, id: \.self) { col in
                    let colRows     = columnRows(col)
                    let count       = min(model.columnFills[col] ?? 0, colRows)
                    let velocity    = model.columnVelocities[col] ?? 88
                    let activeStart = colRows - count

                    VStack(spacing: metrics.rowGap) {
                        ForEach(0..<colRows, id: \.self) { row in
                            let isActive = count > 0 && row >= activeStart
                            Circle()
                                .fill(dotColor(isActive: isActive, velocity: velocity))
                                .frame(width: metrics.dotSize, height: metrics.dotSize)
                                .shadow(color: Color(red:0.545,green:0.357,blue:0.678).opacity(isActive ? 0.5 : 0), radius: 4)
                                .animation(.easeOut(duration: 0.08), value: isActive)
                                .animation(.easeOut(duration: 0.08), value: velocity)
                        }
                    }
                }
            }
            .frame(width: metrics.totalWidth, height: metrics.totalHeight)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
    }

    private func dotColor(isActive: Bool, velocity: UInt8) -> Color {
        guard isActive else { return Color.white.opacity(0.75) }
        let t = min(1.0, max(0.0, Double(velocity - 48) / 79))
        return Color(red: 0.545 + 0.15*(1-t),
                     green: 0.357 + 0.10*(1-t),
                     blue:  0.678 - 0.05*t)
    }
}

// MARK: - 2. Circular Dots

struct CircularDotsVisualizer: View {
    @ObservedObject var model: PracticeVisualizerModel

    private let rings: [(count: Int, radiusFactor: CGFloat)] = [
        (count: 6,  radiusFactor: 0.12),
        (count: 12, radiusFactor: 0.24),
        (count: 18, radiusFactor: 0.37),
        (count: 24, radiusFactor: 0.51),
        (count: 32, radiusFactor: 0.65),
        (count: 40, radiusFactor: 0.80),
    ]
    private let dotSize: CGFloat = 11

    var body: some View {
        GeometryReader { geo in
            let radius  = min(geo.size.width, geo.size.height) / 2
            let center  = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let columns = PracticeVisualizerModel.columnCount
            let rows    = PracticeVisualizerModel.rowCount
            let centerFill = model.columnFills[columns / 2] ?? 0

            ZStack {
                Circle()
                    .fill(blueDot(isActive: centerFill > 0,
                                  velocity: model.columnVelocities[columns / 2] ?? 88))
                    .frame(width: centerFill > 0 ? dotSize + 2 : dotSize,
                           height: centerFill > 0 ? dotSize + 2 : dotSize)
                    .shadow(color: Color(red:0.20,green:0.60,blue:1.0).opacity(centerFill > 0 ? 0.7 : 0), radius: 5)
                    .position(center)
                    .animation(.spring(response: 0.2, dampingFraction: 0.5), value: centerFill)

                ForEach(Array(rings.enumerated()), id: \.offset) { ringIdx, ring in
                    let ringRadius = radius * ring.radiusFactor
                    ForEach(0..<ring.count, id: \.self) { dotIdx in
                        let angle    = (2 * Double.pi / Double(ring.count)) * Double(dotIdx) - Double.pi / 2
                        let x        = center.x + ringRadius * CGFloat(cos(angle))
                        let y        = center.y + ringRadius * CGFloat(sin(angle))
                        let col      = (dotIdx * columns / ring.count) % columns
                        let fill     = model.columnFills[col] ?? 0
                        let isActive = fill > (rows - ringIdx - 2)
                        let velocity = model.columnVelocities[col] ?? 88
                        let size     = isActive ? dotSize + 2 : dotSize

                        Circle()
                            .fill(blueDot(isActive: isActive, velocity: velocity))
                            .frame(width: size, height: size)
                            .shadow(color: Color(red:0.20,green:0.60,blue:1.0).opacity(isActive ? 0.6 : 0), radius: 5)
                            .position(x: x, y: y)
                            .animation(.spring(response: 0.2, dampingFraction: 0.5), value: isActive)
                    }
                }
            }
        }
    }

    private func blueDot(isActive: Bool, velocity: UInt8) -> Color {
        guard isActive else { return Color.white.opacity(0.75) }
        let t = min(1.0, max(0.0, Double(velocity - 48) / 79))
        return Color(red: 0.10 + 0.20*(1-t), green: 0.50 + 0.20*(1-t), blue: 1.0)
    }
}

// MARK: - 3. Waveform

struct WaveformVisualizer: View {
    @ObservedObject var model: PracticeVisualizerModel

    private let columns = PracticeVisualizerModel.columnCount
    private let rows    = PracticeVisualizerModel.rowCount

    private var isActive: Bool {
        model.columnFills.values.contains { $0 > 0 }
    }

    var body: some View {
        let fills = model.columnFills
        let total = fills.values.reduce(0, +)

        GeometryReader { _ in
            ZStack {
                waveLayer(fills: fills, phase: .pi * 0.9, amp: 0.70,
                          color: isActive ? Color(red:0.60,green:0.35,blue:1.0) : .white.opacity(0.3),
                          lineWidth: 6, glowWidth: 18, glowOpacity: isActive ? 0.12 : 0.04)

                waveLayer(fills: fills, phase: .pi * 0.45, amp: 0.85,
                          color: isActive ? Color(red:1.0,green:0.45,blue:0.85) : .white.opacity(0.5),
                          lineWidth: 7, glowWidth: 22, glowOpacity: isActive ? 0.15 : 0.04)

                waveLayer(fills: fills, phase: 0, amp: 1.0,
                          color: isActive ? Color(red:0.78,green:0.55,blue:1.0) : .white.opacity(0.85),
                          lineWidth: 9, glowWidth: 28, glowOpacity: isActive ? 0.20 : 0.05)
            }
            .animation(.easeOut(duration: 0.08), value: total)
            .animation(.easeInOut(duration: 0.3), value: isActive)
        }
    }

    private func waveLayer(fills: [Int:Int], phase: Double, amp: CGFloat,
                           color: Color, lineWidth: CGFloat,
                           glowWidth: CGFloat, glowOpacity: Double) -> some View {
        ZStack {
            WavePath(fills: fills, columns: columns, rows: rows, phaseShift: phase, ampFactor: amp)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            WavePath(fills: fills, columns: columns, rows: rows, phaseShift: phase, ampFactor: amp)
                .stroke(color, style: StrokeStyle(lineWidth: glowWidth, lineCap: .round, lineJoin: .round))
                .opacity(glowOpacity)
        }
    }
}

private struct WavePath: Shape {
    let fills: [Int: Int]
    let columns: Int
    let rows: Int
    let phaseShift: Double
    let ampFactor: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard columns > 1 else { return path }
        let stepX  = rect.width / CGFloat(columns - 1)
        let midY   = rect.midY
        let maxAmp = rect.height * 0.46 * ampFactor

        for col in 0..<columns {
            let fill = fills[col] ?? 0
            let norm = CGFloat(fill) / CGFloat(rows)
            let x    = CGFloat(col) * stepX
            let y    = midY - norm * maxAmp * CGFloat(sin(phaseShift + Double(col) * 0.35))

            if col == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                let px = CGFloat(col-1) * stepX
                let pf = fills[col-1] ?? 0
                let py = midY - CGFloat(pf)/CGFloat(rows) * maxAmp * CGFloat(sin(phaseShift + Double(col-1)*0.35))
                path.addCurve(to: CGPoint(x: x, y: y),
                              control1: CGPoint(x: px + stepX*0.45, y: py),
                              control2: CGPoint(x: x  - stepX*0.45, y: y))
            }
        }
        return path
    }
}





