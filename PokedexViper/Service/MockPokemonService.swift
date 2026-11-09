import Foundation

struct MockPokemonService: PokemonServiceProtocol {
    func fetchPokemonList(url: URL?) async throws -> ServiceValue<PokemonListResponse> {
        ServiceValue(
            value: PokemonListResponse(
                count: 1, next: nil, previous: nil,
                results: [PokemonResults(name: "pikachu", url: "https://pokeapi.co/api/v2/pokemon/25/")]))
    }

    func fetchPokemonDetails(url: String) async throws -> ServiceValue<PokemonDetailsResponse> {
        ServiceValue(value: Self.pikachu)
    }

    func fetchSpecies(url: String) async throws -> ServiceValue<SpeciesDetailsResponse> {
        ServiceValue(value: SpeciesDetailsResponse(flavorTextEntries: [], evolutionChain: nil, varieties: nil))
    }

    func fetchEvolutionChain(url: String) async throws -> ServiceValue<EvolutionChainResponse> {
        throw APIError.invalidResponse
    }

    func fetchSpeciesDescription(url: String) async throws -> String? { "An electric Pokémon." }

    static let pikachu = PokemonDetailsResponse(
        id: 25, name: "pikachu", height: 4, weight: 60,
        types: [PokemonTypeResponse(type: PokemonTypeData(name: "electric", url: ""))],
        abilities: [], stats: [Stat(baseStat: 35, effort: 0, stat: StatDetails(name: "hp", url: ""))],
        moves: [],
        sprites: Sprites(
            other: Other(
                officialArtwork: OfficialArtwork(
                    frontDefault:
                        "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/25.png",
                    frontShiny: nil))),
        species: Species(name: "pikachu", url: "https://pokeapi.co/api/v2/pokemon-species/25/"))
}
