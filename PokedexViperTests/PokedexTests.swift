import Foundation
import Testing

#if canImport(PokedexCore)
    @testable import PokedexCore
#else
    @testable import PokedexViper
#endif

private let pokemonJSON =
    #"{"id":25,"name":"pikachu","height":4,"weight":60,"types":[{"type":{"name":"electric","url":"https://pokeapi.co/api/v2/type/13/"}}],"abilities":[],"stats":[{"base_stat":35,"effort":0,"stat":{"name":"hp","url":""}}],"moves":[],"sprites":{"other":{"official-artwork":{"front_default":"https://example.com/25.png","front_shiny":null}}},"species":{"name":"pikachu","url":"https://example.com/species/25/"}}"#

// URLProtocol callbacks use Foundation's threading model; this stub has no mutable shared state.
private final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let url = request.url else { return }
        if url.path == "/offline" {
            client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
            return
        }
        let status = Int(url.lastPathComponent) ?? 200
        let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        let body: String
        if url.path == "/species" {
            body =
                #"{"flavor_text_entries":[{"flavor_text":"English\ntext.\fNext.","language":{"name":"en","url":""}}]}"#
        } else {
            body = url.path == "/malformed" ? "{}" : pokemonJSON
        }
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

private func makeClient() -> APIClient {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [StubURLProtocol.self]
    return APIClient(session: URLSession(configuration: configuration))
}

struct APIClientTests {
    @Test func decodesSnakeCaseAndHyphenatedArtwork() async throws {
        let result: PokemonDetailsResponse = try await makeClient().request(
            url: URL(string: "https://test.local/pokemon")!)
        #expect(result.stats.first?.baseStat == 35)
        #expect(result.sprites.other?.officialArtwork?.frontDefault == "https://example.com/25.png")
        #expect(result.sprites.other?.officialArtwork?.frontShiny == nil)
    }

    @Test(arguments: [404, 500]) func rejectsHTTPStatusBeforeDecoding(status: Int) async {
        await #expect(throws: APIError.httpStatus(status)) {
            let _: PokemonDetailsResponse = try await makeClient().request(
                url: URL(string: "https://test.local/\(status)")!)
        }
    }

    @Test func decodingErrorIsTyped() async {
        await #expect(throws: APIError.decoding) {
            let _: PokemonDetailsResponse = try await makeClient().request(
                url: URL(string: "https://test.local/malformed")!)
        }
    }

    @Test func offlineErrorIsTyped() async {
        await #expect(throws: APIError.offline) {
            let _: PokemonDetailsResponse = try await makeClient().request(
                url: URL(string: "https://test.local/offline")!)
        }
    }
}

private actor CountingClient: HTTPClientProtocol {
    var count = 0
    let error: APIError?
    init(error: APIError? = nil) { self.error = error }
    func request<T: Decodable & Sendable>(url: URL) async throws -> T {
        count += 1
        if let error { throw error }
        if T.self == PokemonListResponse.self {
            return try JSONDecoder().decode(
                T.self,
                from: Data(#"{"count":1,"results":[{"name":"pikachu","url":"https://test.local/25/"}]}"#.utf8)
            )
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(T.self, from: Data(pokemonJSON.utf8))
    }
}

struct CacheAndInteractorTests {
    @Test func serviceOwnsCacheAndInteractorDoesNotRepeatRequests() async throws {
        let client = CountingClient()
        let service = PokemonService(client: client, cache: PokemonCache(directory: nil))
        let interactor = SearchInteractor(pokemonService: service)
        _ = try await interactor.getPokemonList(url: nil)
        _ = try await interactor.getPokemonList(url: nil)
        let first = try await interactor.getPokemonDetails(url: "https://test.local/25/")
        let second = try await interactor.getPokemonDetails(url: "https://test.local/25/")
        #expect(await client.count == 2)
        #expect(first.value == second.value)
        #expect(first.value.weight == 6)
        #expect(first.value.height == 0.4)
    }

    @Test func diskCacheExpiresButCanSupplyOfflineFallback() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let list = PokemonListResponse(count: 0, next: nil, previous: nil, results: [])
        let date = Date(timeIntervalSince1970: 1000)
        let cache = PokemonCache(directory: directory, ttl: 60, now: { date })
        await cache.save(list, for: PokemonService.firstPage.absoluteString)
        let reopened = PokemonCache(
            directory: directory, ttl: 60, now: { date.addingTimeInterval(61) })
        #expect(await reopened.list(for: PokemonService.firstPage.absoluteString) == nil)
        #expect(
            await reopened.list(for: PokemonService.firstPage.absoluteString, allowExpired: true)?.count == 0)
        let service = PokemonService(client: CountingClient(error: .offline), cache: reopened)
        let result = try await service.fetchPokemonList()
        #expect(result.isOffline)
        #expect(result.value.results.isEmpty)
        let failing = PokemonService(client: CountingClient(error: .httpStatus(500)), cache: reopened)
        await #expect(throws: APIError.httpStatus(500)) { try await failing.fetchPokemonList() }
    }

    @Test func invalidURLDoesNotCallClient() async {
        let client = CountingClient()
        let service = PokemonService(client: client, cache: PokemonCache(directory: nil))
        await #expect(throws: APIError.invalidURL) { try await service.fetchPokemonDetails(url: "invalid") }
        #expect(await client.count == 0)
    }

    @Test(arguments: ["https://pokeapi.co/api/v2/pokemon/25/", "https://pokeapi.co/api/v2/pokemon/25"])
    func extractsIDWithOrWithoutTrailingSlash(url: String) {
        #expect(URL(string: url)?.pokemonID == 25)
    }
}

private actor Gate {
    private var entered = false
    private var entryWaiter: CheckedContinuation<Void, Never>?
    private var releaseWaiter: CheckedContinuation<Void, Never>?
    func wait() async {
        entered = true
        entryWaiter?.resume()
        entryWaiter = nil
        await withCheckedContinuation { releaseWaiter = $0 }
    }
    func waitForEntry() async {
        if entered { return }
        await withCheckedContinuation { entryWaiter = $0 }
    }
    func release() {
        releaseWaiter?.resume()
        releaseWaiter = nil
    }
}

private actor MockInteractor: SearchInteractorProtocol {
    let count: Int
    let gate: Gate?
    var failure: APIError?
    var failedIDs: Set<Int>
    let detailGate: Gate?
    var active = 0
    var peak = 0
    var listCalls = 0
    var detailCalls = 0
    var next: URL?

    init(
        count: Int = 12, gate: Gate? = nil, failure: APIError? = nil, failedIDs: Set<Int> = [],
        next: URL? = nil, detailGate: Gate? = nil
    ) {
        self.count = count
        self.gate = gate
        self.failure = failure
        self.failedIDs = failedIDs
        self.next = next
        self.detailGate = detailGate
    }
    func recover() {
        failedIDs = []
        failure = nil
    }
    func getPokemonList(url: URL?) async throws -> PokemonPage {
        listCalls += 1
        if let gate { await gate.wait() }
        try Task.checkCancellation()
        if let failure { throw failure }
        let offset = url == nil ? 0 : count
        let results = (0..<count).map {
            PokemonResults(name: "pokemon-\($0 + offset + 1)", url: "https://test.local/\($0 + offset + 1)/")
        }
        return PokemonPage(results: results, next: url == nil ? next : nil, isOffline: false)
    }
    func getPokemonDetails(url: String) async throws -> ServiceValue<Pokemon> {
        active += 1
        detailCalls += 1
        peak = max(peak, active)
        defer { active -= 1 }
        if let detailGate { await detailGate.wait() }
        try await Task.sleep(for: .milliseconds(10))
        let id = URL(string: url)!.pokemonID!
        if failedIDs.contains(id) { throw APIError.offline }
        var response = MockPokemonService.pikachu
        response = PokemonDetailsResponse(
            id: id, name: "pokemon-\(id)", height: response.height,
            weight: response.weight, types: response.types, abilities: response.abilities,
            stats: response.stats,
            moves: response.moves, sprites: response.sprites, species: response.species)
        return ServiceValue(value: Pokemon(response: response))
    }
    func getDescription(for pokemon: Pokemon) async throws -> String? { "Description" }
}

@MainActor
struct PresenterTests {
    @Test func initializationHasNoNetworkSideEffectsAndLoadingIsObservable() async {
        let gate = Gate()
        let interactor = MockInteractor(gate: gate)
        let presenter = SearchPresenter(interactor: interactor)
        #expect(presenter.state == .idle)
        #expect(await interactor.listCalls == 0)
        let task = Task { await presenter.fetchPokemonList() }
        await gate.waitForEntry()
        #expect(presenter.state == .loading)
        await gate.release()
        await task.value
        #expect(!presenter.isLoadingPage)
    }

    @Test func concurrencyIsBoundedAndResultsStayOrdered() async {
        let interactor = MockInteractor(count: 19)
        let presenter = SearchPresenter(interactor: interactor)
        await presenter.fetchPokemonList()
        #expect(await interactor.peak == 6)
        guard case .loaded(let pokemon) = presenter.state else {
            Issue.record("Expected loaded state")
            return
        }
        #expect(pokemon.map(\.id) == Array(1...19))
    }

    @Test func emptyAndErrorAlwaysStopLoading() async {
        let empty = SearchPresenter(interactor: MockInteractor(count: 0))
        await empty.fetchPokemonList()
        #expect(empty.state == .empty)
        #expect(!empty.isLoadingPage)
        let failed = SearchPresenter(interactor: MockInteractor(failure: .offline))
        await failed.fetchPokemonList()
        #expect(failed.state == .failed(.offline))
        #expect(!failed.isLoadingPage)
    }

    @Test func partialFailureKeepsSuccessAndRetriesOnlyMissingItems() async {
        let interactor = MockInteractor(count: 4, failedIDs: [2])
        let presenter = SearchPresenter(interactor: interactor)
        await presenter.fetchPokemonList()
        guard case .loaded(let pokemon) = presenter.state else {
            Issue.record("Expected partial success")
            return
        }
        #expect(pokemon.map(\.id) == [1, 3, 4])
        #expect(presenter.failedCount == 1)
        #expect(presenter.isOffline)
        await interactor.recover()
        await presenter.retry()
        #expect(presenter.failedCount == 0)
        #expect(await interactor.detailCalls == 5)
    }

    @Test func cancellationReturnsToIdleAndAllowsRetry() async {
        let gate = Gate()
        let interactor = MockInteractor(gate: gate)
        let presenter = SearchPresenter(interactor: interactor)
        let task = Task { await presenter.fetchPokemonList() }
        await gate.waitForEntry()
        task.cancel()
        await gate.release()
        await task.value
        #expect(presenter.state == .idle)
        #expect(!presenter.isLoadingPage)
        #expect(presenter.pageError == nil)
    }

    @Test func paginationAndFiltersPreservePreviouslyLoadedPages() async {
        let interactor = MockInteractor(count: 2, next: URL(string: "https://test.local/page2"))
        let presenter = SearchPresenter(interactor: interactor)
        await presenter.fetchPokemonList()
        await presenter.loadNextPage()
        #expect(!presenter.canLoadMore)
        presenter.updateFilters(query: "", type: "electric", favoritesOnly: true, favoriteIDs: [4])
        guard case .loaded(let pokemon) = presenter.state else {
            Issue.record("Expected favorite")
            return
        }
        #expect(pokemon.map(\.id) == [4])
        presenter.updateFilters(query: "no-match", type: nil, favoritesOnly: false, favoriteIDs: [])
        #expect(presenter.state == .loading)
        #expect(presenter.isSearching)
    }
}

#if !canImport(PokedexCore)
    import SwiftData

    @MainActor
    struct FavoritesPersistenceTests {
        @Test func favoriteSurvivesReopeningTheStore() throws {
            let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: directory) }
            let configuration = ModelConfiguration(url: directory.appending(path: "Favorites.store"))
            do {
                let container = try ModelContainer(for: FavoritePokemon.self, configurations: configuration)
                let context = ModelContext(container)
                context.insert(FavoritePokemon(pokemonID: 25))
                try context.save()
            }
            let reopened = try ModelContainer(for: FavoritePokemon.self, configurations: configuration)
            let context = ModelContext(reopened)
            let stored = try context.fetch(FetchDescriptor<FavoritePokemon>())
            #expect(stored.map(\.pokemonID) == [25])
            if let favorite = stored.first { context.delete(favorite) }
            try context.save()
            #expect(try context.fetchCount(FetchDescriptor<FavoritePokemon>()) == 0)
        }
    }
#endif

struct AdditionalDataTests {
    @Test func speciesDecodesAndNormalizesWhitespace() async throws {
        let service = PokemonService(client: makeClient(), cache: PokemonCache(directory: nil))
        let description = try await service.fetchSpeciesDescription(url: "https://test.local/species")
        #expect(description == "English text. Next.")
    }

    @Test func imagesRemainAvailableAfterSessionInvalidation() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let cache = URLCache(memoryCapacity: 1_024 * 1_024, diskCapacity: 0, diskPath: nil)
        let loader = PokemonImageLoader(cache: cache, session: session)
        let url = URL(string: "https://test.local/artwork")!
        let first = try await loader.data(for: url)
        session.invalidateAndCancel()
        let cached = try await loader.data(for: url)
        #expect(!first.isEmpty)
        #expect(first == cached)
    }
}

@MainActor
struct AdditionalPresenterTests {
    @Test func cancellationDuringDetailLoadingCancelsChildrenWithoutFailure() async {
        let gate = Gate()
        let interactor = MockInteractor(count: 1, detailGate: gate)
        let presenter = SearchPresenter(interactor: interactor)
        let task = Task { await presenter.fetchPokemonList() }
        await gate.waitForEntry()
        task.cancel()
        await gate.release()
        await task.value
        #expect(presenter.state == .idle)
        #expect(!presenter.isLoadingPage)
        #expect(await interactor.active == 0)
        #expect(presenter.failedCount == 0)
    }

    @Test func totalDetailFailureCanRecoverWithoutReloadingList() async {
        let interactor = MockInteractor(count: 2, failedIDs: [1, 2])
        let presenter = SearchPresenter(interactor: interactor)
        await presenter.fetchPokemonList()
        #expect(presenter.state == .failed(.offline))
        await interactor.recover()
        await presenter.retry()
        guard case .loaded(let pokemon) = presenter.state else {
            Issue.record("Expected recovery")
            return
        }
        #expect(pokemon.count == 2)
        #expect(!presenter.isOffline)
        #expect(await interactor.listCalls == 1)
    }
}


private actor RemoteSearchInteractor: SearchInteractorProtocol {
    let gate: Gate?
    private(set) var searchCalls = 0

    init(gate: Gate? = nil) { self.gate = gate }

    func getPokemonList(url: URL?) async throws -> PokemonPage {
        PokemonPage(
            results: [PokemonResults(name: "pikachu", url: "https://test.local/25/")],
            next: nil, isOffline: false)
    }

    func getPokemonDetails(url: String) async throws -> ServiceValue<Pokemon> {
        ServiceValue(value: Pokemon(response: MockPokemonService.pikachu))
    }

    func getDescription(for pokemon: Pokemon) async throws -> String? { nil }

    func findPokemon(query: String) async throws -> ServiceValue<Pokemon>? {
        searchCalls += 1
        if let gate { await gate.wait() }
        if query == "offline" { throw APIError.offline }
        guard query == "raichu" else { return nil }
        let base = MockPokemonService.pikachu
        return ServiceValue(value: Pokemon(response: PokemonDetailsResponse(
            id: 26, name: "raichu", height: base.height, weight: base.weight,
            types: base.types, abilities: base.abilities, stats: base.stats,
            moves: base.moves, sprites: base.sprites, species: base.species)))
    }
}

@MainActor
struct SearchTransitionTests {
    private func search(_ query: String, in presenter: SearchPresenter) {
        presenter.updateFilters(query: query, type: nil, favoritesOnly: false, favoriteIDs: [])
    }

    @Test func localMissLoadsDuringDebounceAndUntilRemoteSuccess() async {
        let gate = Gate()
        let interactor = RemoteSearchInteractor(gate: gate)
        let presenter = SearchPresenter(interactor: interactor)
        await presenter.fetchPokemonList()

        search("raichu", in: presenter)
        #expect(presenter.state == .loading)
        #expect(presenter.isSearching)
        #expect(await interactor.searchCalls == 0)

        let task = Task { await presenter.searchIfNeeded() }
        await gate.waitForEntry()
        #expect(presenter.state == .loading)
        await gate.release()
        await task.value

        guard case .loaded(let pokemon) = presenter.state else {
            Issue.record("Expected remote results without a premature empty state")
            return
        }
        #expect(pokemon.map(\.id) == [26])
        #expect(!presenter.isSearching)
    }

    @Test func noResultsAppearsOnlyAfterRemoteLookupCompletes() async {
        let interactor = RemoteSearchInteractor()
        let presenter = SearchPresenter(interactor: interactor)
        await presenter.fetchPokemonList()

        search("missing", in: presenter)
        #expect(presenter.state == .loading)
        await presenter.searchIfNeeded()
        #expect(presenter.state == .empty)
        #expect(await interactor.searchCalls == 1)
        #expect(!presenter.isSearching)
    }

    @Test func previousErrorIsClearedBeforeSearchingAnotherQuery() async {
        let presenter = SearchPresenter(interactor: RemoteSearchInteractor())
        await presenter.fetchPokemonList()
        search("offline", in: presenter)
        #expect(presenter.state == .loading)
        await presenter.searchIfNeeded()
        #expect(presenter.state == .failed(.offline))

        search("raichu", in: presenter)
        #expect(presenter.state == .loading)
        #expect(presenter.searchError == nil)
        await presenter.searchIfNeeded()
        guard case .loaded(let pokemon) = presenter.state else {
            Issue.record("Expected results for the new query")
            return
        }
        #expect(pokemon.map(\.id) == [26])
    }

    @Test func localMatchesAppearImmediatelyWithoutRemoteLoading() async {
        let interactor = RemoteSearchInteractor()
        let presenter = SearchPresenter(interactor: interactor)
        await presenter.fetchPokemonList()
        search("pika", in: presenter)
        guard case .loaded(let pokemon) = presenter.state else {
            Issue.record("Expected immediate local results")
            return
        }
        #expect(pokemon.map(\.id) == [25])
        #expect(!presenter.isSearching)
        await presenter.searchIfNeeded()
        #expect(await interactor.searchCalls == 0)
    }

    @Test func clearingQueryDuringDebounceRestoresLocalResults() async {
        let interactor = RemoteSearchInteractor()
        let presenter = SearchPresenter(interactor: interactor)
        await presenter.fetchPokemonList()
        search("raichu", in: presenter)
        #expect(presenter.state == .loading)
        search("", in: presenter)
        await presenter.searchIfNeeded()
        guard case .loaded(let pokemon) = presenter.state else {
            Issue.record("Expected local results after clearing the query")
            return
        }
        #expect(pokemon.map(\.id) == [25])
        #expect(!presenter.isSearching)
        #expect(await interactor.searchCalls == 0)
    }

    @Test func pageArrivingDuringDebounceAvoidsUnnecessaryLookup() async {
        let interactor = RemoteSearchInteractor()
        let presenter = SearchPresenter(interactor: interactor)
        search("pikachu", in: presenter)
        #expect(presenter.state == .loading)
        await presenter.fetchPokemonList()
        await presenter.searchIfNeeded()
        guard case .loaded(let pokemon) = presenter.state else {
            Issue.record("Expected the new local result to end the pending search")
            return
        }
        #expect(pokemon.map(\.id) == [25])
        #expect(!presenter.isSearching)
        #expect(await interactor.searchCalls == 0)
    }
}
