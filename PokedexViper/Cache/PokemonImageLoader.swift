import Foundation

actor PokemonImageLoader {
    static let shared = PokemonImageLoader()
    private let session: URLSession
    private let cache: URLCache
    private var inFlight: [URL: Task<Data, any Error>] = [:]

    init(
        cache: URLCache = URLCache(
            memoryCapacity: 32 * 1_024 * 1_024, diskCapacity: 128 * 1_024 * 1_024,
            diskPath: "pokemon-images"), session: URLSession? = nil
    ) {
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = cache
        self.cache = cache
        self.session = session ?? URLSession(configuration: configuration)
    }

    func data(for url: URL) async throws -> Data {
        let request = URLRequest(url: url)
        if let cached = cache.cachedResponse(for: request) { return cached.data }
        if let task = inFlight[url] { return try await task.value }
        let task = Task { [session, cache] in
            let (data, response) = try await session.data(for: request)
            guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode)
            else {
                throw APIError.invalidResponse
            }
            cache.storeCachedResponse(CachedURLResponse(response: response, data: data), for: request)
            return data
        }
        inFlight[url] = task
        defer { inFlight[url] = nil }
        return try await task.value
    }
}
