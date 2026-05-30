//
//  PracticeVisualizerModel.swift
//  Sensic
//

import Foundation
import Combine

@MainActor
final class PracticeVisualizerModel: ObservableObject {

    static let columnCount = 17
    static let rowCount = 10
    static let persistenceSeconds: TimeInterval = 2

    private static let activeRowCount = rowCount

    @Published private(set) var columnFills: [Int: Int] = [:]
    @Published private(set) var columnVelocities: [Int: UInt8] = [:]

    private struct ActiveNoteMeta {
        var column: Int
        var startedAt: Date
        var velocity: UInt8
        var midi: UInt8
    }

    private var activeMetaByMidi: [UInt8: ActiveNoteMeta] = [:]
    private var peakFillByColumn: [Int: Int] = [:]
    private var peakVelocityByColumn: [Int: UInt8] = [:]
    private var releasedAtByColumn: [Int: Date] = [:]

    func update(
        activeNotes: Set<UInt8>,
        scrollState: PianoScrollState,
        velocities: [UInt8: UInt8] = [:]
    ) {
        let now = Date()
        var fills: [Int: Int] = [:]
        var velocitiesOut: [Int: UInt8] = [:]
        var activeColumns = Set<Int>()

        for midi in activeNotes {
            guard let column = Self.column(for: midi, scrollState: scrollState) else { continue }
            activeColumns.insert(column)
            releasedAtByColumn.removeValue(forKey: column)

            let velocity = velocities[midi] ?? 88
            if var existing = activeMetaByMidi[midi] {
                existing.column = column
                existing.velocity = max(existing.velocity, velocity)
                activeMetaByMidi[midi] = existing
            } else {
                activeMetaByMidi[midi] = ActiveNoteMeta(
                    column: column,
                    startedAt: now,
                    velocity: velocity,
                    midi: midi
                )
            }

            guard let meta = activeMetaByMidi[midi] else { continue }
            let held = now.timeIntervalSince(meta.startedAt)
            let fill = Self.fillHeight(velocity: meta.velocity, holdDuration: held, midi: meta.midi)
            peakFillByColumn[column] = max(peakFillByColumn[column] ?? 0, fill)
            peakVelocityByColumn[column] = max(peakVelocityByColumn[column] ?? 0, meta.velocity)
            fills[column] = peakFillByColumn[column]
            velocitiesOut[column] = peakVelocityByColumn[column]
        }

        for midi in activeMetaByMidi.keys where !activeNotes.contains(midi) {
            if let meta = activeMetaByMidi.removeValue(forKey: midi) {
                let column = meta.column
                peakVelocityByColumn[column] = max(peakVelocityByColumn[column] ?? 0, meta.velocity)
                if releasedAtByColumn[column] == nil {
                    releasedAtByColumn[column] = now
                }
            }
        }

        for column in peakFillByColumn.keys where !activeColumns.contains(column) {
            if let releasedAt = releasedAtByColumn[column],
               now.timeIntervalSince(releasedAt) < Self.persistenceSeconds,
               let peak = peakFillByColumn[column] {
                fills[column] = peak
                velocitiesOut[column] = peakVelocityByColumn[column] ?? 88
            } else {
                peakFillByColumn.removeValue(forKey: column)
                peakVelocityByColumn.removeValue(forKey: column)
                releasedAtByColumn.removeValue(forKey: column)
            }
        }

        columnFills = fills
        columnVelocities = velocitiesOut
    }

    func clear() {
        columnFills = [:]
        columnVelocities = [:]
        activeMetaByMidi.removeAll()
        peakFillByColumn.removeAll()
        peakVelocityByColumn.removeAll()
        releasedAtByColumn.removeAll()
    }

    // MARK: - Fill Height
    // كل نوتة عندها سقف مختلف حسب موقعها على البيانو
    // النوتات الوسط (C4) توصل لـ 10 صفوف، الطرفين أقصاها 2 صفوف

    static func fillHeight(velocity: UInt8, holdDuration: TimeInterval, midi: UInt8) -> Int {
        let velocityCurve = pow(Double(velocity) / 127.0, 0.55)

        // Bell curve مركزها C4 (midi 60)
        let center: Double = 60.0
        let spread: Double = 28.0   // ← كبّري لتوسيع القمة
        let normalized = Double(midi) - center
        let bellShape = exp(-(normalized * normalized) / (2 * spread * spread))
        // bellShape: 1.0 عند C4، ~0.15 عند الأطراف

        let minRows: Double = 2.0
        let maxRows: Double = Double(activeRowCount)   // 10
        let maxFill = minRows + bellShape * (maxRows - minRows)

        let fromVelocity = velocityCurve * maxFill * 0.7
        let fromHold     = min(maxFill * 0.3, holdDuration * 1.5)

        return min(Int(maxFill), max(1, Int(round(fromVelocity + fromHold))))
    }

    // MARK: - Column mapping

    static func column(for midi: UInt8, scrollState: PianoScrollState) -> Int? {
        let viewport = max(scrollState.viewportWidth, 1)
        guard let centerX = keyCenterX(for: midi) else { return nil }

        let relativeX = centerX - scrollState.offset
        guard relativeX >= -wKW, relativeX <= viewport + wKW else { return nil }

        let normalized = min(1, max(0, relativeX / viewport))
        let index = Int(normalized * CGFloat(columnCount - 1))
        return min(columnCount - 1, max(0, index))
    }

    private static func keyCenterX(for midi: UInt8) -> CGFloat? {
        let keyWidth = wKW + 1.5

        if let whiteIndex = whitePianoKeys.firstIndex(where: { $0.midi == midi }) {
            return CGFloat(whiteIndex) * keyWidth + wKW / 2
        }

        if let blackX = blackKeyOffset(midi) {
            return blackX + bKW / 2
        }

        return nil
    }
}
