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
    func getEvolutionFamily(for pokemon: Pokemon) async throws -> ServiceValue<PokemonEvolutionFamily>?
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

    func getEvolutionFamily(for pokemon: Pokemon) async throws -> ServiceValue<PokemonEvolutionFamily>? {
        try Task.checkCancellation()
        let species = try await pokemonService.fetchSpecies(url: pokemon.speciesURL)
        guard let chainURL = species.value.evolutionChain?.url else { return nil }
        let chain = try await pokemonService.fetchEvolutionChain(url: chainURL)
        let references = PokemonEvolutionFamily.references(from: chain.value)
        return try await withThrowingTaskGroup(
            of: (Int, PokemonEvolutionFamily.Member, Bool).self
        ) { group in
            var iterator = references.indices.makeIterator()
            func enqueue(_ index: Int) {
                let reference = references[index]
                group.addTask {
                    let result = try await resolveEvolution(reference, currentPokemon: pokemon)
                    return (index, result.value, result.isOffline)
                }
            }
            for _ in 0..<min(4, references.count) {
                if let index = iterator.next() { enqueue(index) }
            }
            var members: [(Int, PokemonEvolutionFamily.Member)] = []
            var isOffline = species.isOffline || chain.isOffline
            for try await (index, member, memberIsOffline) in group {
                try Task.checkCancellation()
                members.append((index, member))
                isOffline = isOffline || memberIsOffline
                if let next = iterator.next() { enqueue(next) }
            }
            try Task.checkCancellation()
            return ServiceValue(
                value: PokemonEvolutionFamily(members: members.sorted { $0.0 < $1.0 }.map(\.1)),
                isOffline: isOffline)
        }
    }

    private func resolveEvolution(
        _ reference: PokemonEvolutionFamily.Reference, currentPokemon: Pokemon
    ) async throws -> ServiceValue<PokemonEvolutionFamily.Member> {
        try Task.checkCancellation()
        if let speciesID = URL(string: reference.species.url)?.pokemonID,
            speciesID == URL(string: currentPokemon.speciesURL)?.pokemonID
        {
            return ServiceValue(value: .init(reference: reference, pokemon: currentPokemon))
        }
        let species = try await pokemonService.fetchSpecies(url: reference.species.url)
        guard let variety = species.value.varieties?.first(where: \.isDefault) else {
            throw APIError.decoding
        }
        let detail = try await getPokemonDetails(url: variety.pokemon.url)
        try Task.checkCancellation()
        return ServiceValue(
            value: .init(reference: reference, pokemon: detail.value),
            isOffline: species.isOffline || detail.isOffline)
    }

}

// Reuse detail loading so searches share the same cache and offline fallback.
extension SearchInteractorProtocol {
    func getEvolutionFamily(for pokemon: Pokemon) async throws -> ServiceValue<PokemonEvolutionFamily>? { nil }

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
