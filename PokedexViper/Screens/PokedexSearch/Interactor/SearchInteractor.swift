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
