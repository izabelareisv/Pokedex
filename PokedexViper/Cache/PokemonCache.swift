import CryptoKit
import Foundation
import os

struct CacheValue<Value: Codable & Sendable>: Codable, Sendable {
    let value: Value
    let savedAt: Date
}

protocol PokemonCaching: Sendable {
    func list(for key: String, allowExpired: Bool) async -> PokemonListResponse?
    func detail(for key: String, allowExpired: Bool) async -> PokemonDetailsResponse?
    func save(_ list: PokemonListResponse, for key: String) async
    func save(_ detail: PokemonDetailsResponse, for key: String) async
}

actor PokemonCache: PokemonCaching {
    private let directory: URL?
    private let ttl: TimeInterval
    private let now: @Sendable () -> Date
    private var lists: [String: CacheValue<PokemonListResponse>] = [:]
    private var details: [String: CacheValue<PokemonDetailsResponse>] = [:]
    private let logger = Logger(subsystem: "com.PokedexViper", category: "Cache")

    init(
        directory: URL? = URL.cachesDirectory.appending(path: "Pokedex", directoryHint: .isDirectory),
        ttl: TimeInterval = 86_400, now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.directory = directory
        self.ttl = ttl
        self.now = now
    }

    func list(for key: String, allowExpired: Bool = false) -> PokemonListResponse? {
        let entry = lists[key] ?? read(PokemonListResponse.self, key: key)
        lists[key] = entry
        return valid(entry, allowExpired: allowExpired)
    }

    func detail(for key: String, allowExpired: Bool = false) -> PokemonDetailsResponse? {
        let entry = details[key] ?? read(PokemonDetailsResponse.self, key: key)
        details[key] = entry
        return valid(entry, allowExpired: allowExpired)
    }

    func save(_ list: PokemonListResponse, for key: String) {
        let entry = CacheValue(value: list, savedAt: now())
        lists[key] = entry
        write(entry, key: key)
    }

    func save(_ detail: PokemonDetailsResponse, for key: String) {
        let entry = CacheValue(value: detail, savedAt: now())
        details[key] = entry
        write(entry, key: key)
    }

    private func valid<T>(_ entry: CacheValue<T>?, allowExpired: Bool) -> T? {
        guard let entry, allowExpired || now().timeIntervalSince(entry.savedAt) < ttl else { return nil }
        return entry.value
    }

    private func file(for key: String) -> URL? {
        let hash = SHA256.hash(data: Data(key.utf8)).map { String(format: "%02x", $0) }.joined()
        return directory?.appending(path: hash + ".json")
    }

    private func read<T>(_ type: T.Type, key: String) -> CacheValue<T>? {
        guard let file = file(for: key), let data = try? Data(contentsOf: file) else { return nil }
        return try? JSONDecoder().decode(CacheValue<T>.self, from: data)
    }

    private func write<T>(_ entry: CacheValue<T>, key: String) {
        guard let directory, let file = file(for: key) else { return }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try JSONEncoder().encode(entry).write(to: file, options: .atomic)
        } catch { logger.error("Could not persist cache: \(error.localizedDescription, privacy: .public)") }
    }
}
