//
//  APIClient.swift
//  Sensic
//
//  Created by Bushra Hatim Alhejaili on 30/05/2026.
//


import Foundation


final class APIClient {
    static let shared = APIClient()

    var authToken: String?

    private let base    = URL(string: "https://api.sensic.app/v1")!
    private let session = URLSession.shared

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private init() {}

    func get<T: Decodable>(_ path: String) async throws -> T {
        try await perform(makeRequest(path, method: "GET"))
    }

    func post<B: Encodable, T: Decodable>(_ path: String, body: B) async throws -> T {
        var req = makeRequest(path, method: "POST")
        req.httpBody = try encoder.encode(body)
        return try await perform(req)
    }

    func delete(_ path: String) async throws {
        _ = try await session.data(for: makeRequest(path, method: "DELETE"))
    }

    private func makeRequest(_ path: String, method: String) -> URLRequest {
        var req = URLRequest(url: base.appendingPathComponent(path))
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = authToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return req
    }

    private func perform<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw APIError.httpError(http.statusCode)
        }
        do { return try decoder.decode(T.self, from: data) }
        catch { throw APIError.decodingError(error) }
    }
}
