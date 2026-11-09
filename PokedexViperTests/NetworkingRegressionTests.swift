import Foundation
import Testing

#if canImport(PokedexCore)
    @testable import PokedexCore
#else
    @testable import PokedexViper
#endif

struct NetworkingRegressionTests {
    @Test func notFoundBecomesNoResultWhileServerErrorsStayRetryableErrors() async throws {
        let missing = SearchInteractor(pokemonService: PokemonService(
            client: RegressionHTTPClient(status: 404), cache: PokemonCache(directory: nil)))
        let result = try await missing.findPokemon(query: "missing")
        #expect(result == nil)
        let unavailable = SearchInteractor(pokemonService: PokemonService(
            client: RegressionHTTPClient(status: 500), cache: PokemonCache(directory: nil)))
        do {
            _ = try await unavailable.findPokemon(query: "pokemon-25")
            Issue.record("A server failure must not be shown as no matching Pokémon")
        } catch {
            #expect(APIError.map(error) == .httpStatus(500))
        }
    }

    @Test func invalidQueriesDoNotBecomeRequestPaths() async throws {
        let client = RegressionHTTPClient()
        let interactor = SearchInteractor(pokemonService: PokemonService(client: client, cache: PokemonCache(directory: nil)))
        for query in ["../25", "pikachu?foo", "pikachu/25", ""] {
            let result = try await interactor.findPokemon(query: query)
            #expect(result == nil)
        }
        let urls = await client.urls
        #expect(urls.isEmpty)
    }

    @Test func numericSearchBuildsACanonicalURLAndReturnsDomainValues() async throws {
        let client = RegressionHTTPClient()
        let interactor = SearchInteractor(pokemonService: PokemonService(client: client, cache: PokemonCache(directory: nil)))
        let result = try #require(try await interactor.findPokemon(query: "25"))
        #expect(result.value.id == 25)
        #expect(result.value.weight == 6)
        #expect(result.value.height == 0.4)
        let urls = await client.urls
        #expect(urls.map(\.absoluteString) == ["https://pokeapi.co/api/v2/pokemon/25/"])
    }

    @Test func transportErrorsKeepTheirMeaningAndUserFacingMessages() {
        let cases: [(URLError.Code, APIError)] = [
            (.notConnectedToInternet, .offline), (.networkConnectionLost, .offline),
            (.secureConnectionFailed, .certificateTrust), (.timedOut, .transport)
        ]
        for (code, expected) in cases { #expect(APIError.map(URLError(code)) == expected) }
        #expect(APIError.map(APIError.httpStatus(503)) == .httpStatus(503))
        let errors: [APIError] = [.invalidURL, .invalidResponse, .httpStatus(500), .decoding, .offline, .certificateTrust, .transport]
        for error in errors { #expect(!error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
    }
}
