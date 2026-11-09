import Foundation

struct ServiceValue<Value: Sendable>: Sendable {
    let value: Value
    var isOffline = false
}

protocol PokemonServiceProtocol: Sendable {
    func fetchPokemonList(url: URL?) async throws -> ServiceValue<PokemonListResponse>
    func fetchPokemonDetails(url: String) async throws -> ServiceValue<PokemonDetailsResponse>
    func fetchSpecies(url: String) async throws -> ServiceValue<SpeciesDetailsResponse>
    func fetchEvolutionChain(url: String) async throws -> ServiceValue<EvolutionChainResponse>
    func fetchSpeciesDescription(url: String) async throws -> String?
}

struct PokemonService: PokemonServiceProtocol {
    static let firstPage = URL(string: "https://pokeapi.co/api/v2/pokemon?offset=0&limit=24")!
    private let client: any HTTPClientProtocol
    private let cache: any PokemonCaching

    init(client: any HTTPClientProtocol = APIClient(), cache: any PokemonCaching = PokemonCache()) {
        self.client = client
        self.cache = cache
    }

    func fetchPokemonList(url: URL? = nil) async throws -> ServiceValue<PokemonListResponse> {
        let url = url ?? Self.firstPage
        if let cached = await cache.list(for: url.absoluteString, allowExpired: false) {
            return ServiceValue(value: cached)
        }
        do {
            let list: PokemonListResponse = try await client.request(url: url)
            await cache.save(list, for: url.absoluteString)
            return ServiceValue(value: list)
        } catch {
            if APIError.map(error) == .offline,
                let cached = await cache.list(for: url.absoluteString, allowExpired: true)
            {
                return ServiceValue(value: cached, isOffline: true)
            }
            throw error
        }
    }

    func fetchPokemonDetails(url: String) async throws -> ServiceValue<PokemonDetailsResponse> {
        guard let endpoint = URL(string: url), ["https", "http"].contains(endpoint.scheme) else {
            throw APIError.invalidURL
        }
        if let cached = await cache.detail(for: url, allowExpired: false) {
            return ServiceValue(value: cached)
        }
        do {
            let detail: PokemonDetailsResponse = try await client.request(url: endpoint)
            await cache.save(detail, for: url)
            return ServiceValue(value: detail)
        } catch {
            if APIError.map(error) == .offline, let cached = await cache.detail(for: url, allowExpired: true)
            {
                return ServiceValue(value: cached, isOffline: true)
            }
            throw error
        }
    }

    func fetchSpecies(url: String) async throws -> ServiceValue<SpeciesDetailsResponse> {
        guard let endpoint = URL(string: url), ["https", "http"].contains(endpoint.scheme) else {
            throw APIError.invalidURL
        }
        if let cached = await cache.species(for: url, allowExpired: false) {
            return ServiceValue(value: cached)
        }
        do {
            let species: SpeciesDetailsResponse = try await client.request(url: endpoint)
            await cache.save(species, for: url)
            return ServiceValue(value: species)
        } catch {
            if APIError.map(error) == .offline,
                let cached = await cache.species(for: url, allowExpired: true)
            {
                return ServiceValue(value: cached, isOffline: true)
            }
            throw error
        }
    }

    func fetchEvolutionChain(url: String) async throws -> ServiceValue<EvolutionChainResponse> {
        guard let endpoint = URL(string: url), ["https", "http"].contains(endpoint.scheme) else {
            throw APIError.invalidURL
        }
        if let cached = await cache.evolution(for: url, allowExpired: false) {
            return ServiceValue(value: cached)
        }
        do {
            let evolution: EvolutionChainResponse = try await client.request(url: endpoint)
            await cache.save(evolution, for: url)
            return ServiceValue(value: evolution)
        } catch {
            if APIError.map(error) == .offline,
                let cached = await cache.evolution(for: url, allowExpired: true)
            {
                return ServiceValue(value: cached, isOffline: true)
            }
            throw error
        }
    }

    func fetchSpeciesDescription(url: String) async throws -> String? {
        let species = try await fetchSpecies(url: url).value
        // Keep API content consistent with the English interface on every device.
        let entry = species.flavorTextEntries.first { $0.language.name == "en" }
        return entry?.flavorText.replacingOccurrences(of: "\n", with: " ").replacingOccurrences(
            of: "\u{000C}", with: " ")
    }
}
