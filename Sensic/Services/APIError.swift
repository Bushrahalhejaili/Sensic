//
//  APIError.swift
//  Sensic
//
//  Created by Bushra Hatim Alhejaili on 30/05/2026.
//

import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case httpError(Int)
    case decodingError(Error)
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:           return "Invalid URL"
        case .httpError(let code):  return "Server error \(code)"
        case .decodingError(let e): return "Decode error: \(e.localizedDescription)"
        case .unknown(let e):       return e.localizedDescription
        }
    }
}
