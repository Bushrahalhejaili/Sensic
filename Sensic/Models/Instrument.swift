//
//  Instrument.swift
//  Sensic
//

import Foundation

enum InstrumentKind: String, CaseIterable, Identifiable {
    case piano
    case strings
    case drums

    var id: String { rawValue }
}


