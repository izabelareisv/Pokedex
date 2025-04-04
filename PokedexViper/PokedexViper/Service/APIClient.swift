//
//  APIClient.swift
//  PokedexViper
//
//  Created by Izabela Reis on 02/04/25.
//

import Foundation

final class APIClient {
    static let shared = APIClient() // Singleton

    private init() {}

    /// Performs a GET request and decodes the response into the expected model
    func request<T: Decodable>(url endpoint: URL) async throws -> T {
        let (data, _) = try await URLSession.shared.data(from: endpoint)

        if let jsonString = String(data: data, encoding: .utf8) {
            print("[APIClient] Received JSON: \(jsonString)")
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            print("[APIClient] Decoding error: \(error)")
            throw error
        }
    }
}
