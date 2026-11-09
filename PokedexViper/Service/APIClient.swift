import Foundation
import os

enum APIError: Error, Equatable, Sendable, LocalizedError {
    case invalidURL
    case invalidResponse
    case httpStatus(Int)
    case decoding
    case offline
    case certificateTrust
    case transport

    var errorDescription: String? {
        switch self {
        case .invalidURL: "The Pokémon address is invalid."
        case .invalidResponse: "The server returned an invalid response."
        case .httpStatus: "The server is unavailable. Please try again."
        case .decoding: "The Pokémon data could not be read."
        case .offline: "You are offline. Check your connection and try again."
        case .certificateTrust:
            "The network certificate is not trusted. Try another network or contact your IT administrator."
        case .transport: "Could not connect. Please try again."
        }
    }

    static func map(_ error: any Error) -> APIError {
        if let error = error as? APIError { return error }
        if let error = error as? URLError {
            if [.notConnectedToInternet, .networkConnectionLost].contains(error.code) {
                return .offline
            }
            if error.code == .secureConnectionFailed {
                return .certificateTrust
            }
        }
        return .transport
    }
}

protocol HTTPClientProtocol: Sendable {
    func request<T: Decodable & Sendable>(url: URL) async throws -> T
}

struct APIClient: HTTPClientProtocol {
    private let session: URLSession
    private let logger = Logger(subsystem: "com.PokedexViper", category: "Networking")

    init(session: URLSession = .shared) { self.session = session }

    func request<T: Decodable & Sendable>(url: URL) async throws -> T {
        do {
            try Task.checkCancellation()
            logger.debug("GET \(url.path, privacy: .public)")
            let (data, response) = try await session.data(from: url)
            guard let response = response as? HTTPURLResponse else { throw APIError.invalidResponse }
            guard (200..<300).contains(response.statusCode) else {
                logger.error("HTTP status: \(response.statusCode)")
                throw APIError.httpStatus(response.statusCode)
            }
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            do { return try decoder.decode(T.self, from: data) } catch {
                logger.error("Response decoding failed for \(String(describing: T.self), privacy: .public)")
                throw APIError.decoding
            }
        } catch {
            if error is CancellationError || (error as? URLError)?.code == .cancelled {
                throw CancellationError()
            }
            throw APIError.map(error)
        }
    }
}
