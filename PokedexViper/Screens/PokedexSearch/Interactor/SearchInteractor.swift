import Foundation

struct PokemonPage: Sendable {
    let results: [PokemonResults]
    let next: URL?
    let isOffline: Bool
}

protocol SearchInteractorProtocol: Sendable {
    func getPokemonList(url: URL?) async throws -> PokemonPage
    func getPokemonDetails(url: String) async throws -> ServiceValue<Pokemon>
    func getDescription(for pokemon: Pokemon) async throws -> String?
    func findPokemon(query: String) async throws -> ServiceValue<Pokemon>?
}

struct SearchInteractor: SearchInteractorProtocol {
    private let pokemonService: any PokemonServiceProtocol

    init(pokemonService: any PokemonServiceProtocol) { self.pokemonService = pokemonService }

    func getPokemonList(url: URL?) async throws -> PokemonPage {
        let response = try await pokemonService.fetchPokemonList(url: url)
        return PokemonPage(
            results: response.value.results, next: response.value.next.flatMap(URL.init(string:)),
            isOffline: response.isOffline)
    }

    func getPokemonDetails(url: String) async throws -> ServiceValue<Pokemon> {
        let response = try await pokemonService.fetchPokemonDetails(url: url)
        return ServiceValue(value: Pokemon(response: response.value), isOffline: response.isOffline)
    }

    func getDescription(for pokemon: Pokemon) async throws -> String? {
        try await pokemonService.fetchSpeciesDescription(url: pokemon.speciesURL)
    }
}

// Reuse detail loading so searches share the same cache and offline fallback.
extension SearchInteractorProtocol {
    func findPokemon(query: String) async throws -> ServiceValue<Pokemon>? {
        guard query.range(of: "^[a-z0-9-]+$", options: .regularExpression) != nil else {
            return nil
        }
        let url = URL(string: "https://pokeapi.co/api/v2/pokemon/")!
            .appendingPathComponent(query, isDirectory: true)
        do {
            return try await getPokemonDetails(url: url.absoluteString)
        } catch APIError.httpStatus(404) {
            return nil
        }
    }
}
