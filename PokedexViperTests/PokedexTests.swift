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

struct PokemonComparisonTests {
    private func pokemon(_ id: Int, stats: [(String, Int)] = [("hp", 35)]) -> Pokemon {
        let base = MockPokemonService.pikachu
        return Pokemon(response: PokemonDetailsResponse(
            id: id, name: "pokemon-\(id)", height: base.height, weight: base.weight,
            types: base.types, abilities: base.abilities,
            stats: stats.map { Stat(baseStat: $0.1, effort: 0, stat: StatDetails(name: $0.0, url: "")) },
            moves: base.moves, sprites: base.sprites, species: base.species))
    }

    @Test func comparisonRequiresTwoDifferentPokemon() {
        let first = pokemon(25)
        #expect(PokemonComparison(first: first, second: first) == nil)
        #expect(PokemonComparison(first: first, second: pokemon(25, stats: [("hp", 60)])) == nil)
        #expect(PokemonComparison(first: first, second: pokemon(26)) != nil)
    }

    @Test func selectionLimitsThePairWithoutReplacingAnExistingPick() {
        var selection = PokemonComparisonSelection()
        #expect(selection.comparison == nil)
        selection.toggle(pokemon(25))
        #expect(selection.comparison == nil)
        selection.toggle(pokemon(26))
        selection.toggle(pokemon(94))
        #expect(selection.pokemon.map(\.id) == [25, 26])
        #expect(selection.isFull)
        #expect(selection.comparison?.first.id == 25)
        #expect(selection.comparison?.second.id == 26)
    }

    @Test func selectionUsesIdentityAndAllowsReplacementOrCancellation() {
        var selection = PokemonComparisonSelection()
        selection.toggle(pokemon(25))
        selection.toggle(pokemon(26))
        selection.toggle(pokemon(25, stats: [("hp", 60)]))
        #expect(selection.pokemon.map(\.id) == [26])
        #expect(selection.comparison == nil)
        selection.toggle(pokemon(94))
        #expect(selection.comparison?.first.id == 26)
        #expect(selection.comparison?.second.id == 94)
        selection.remove(id: 26)
        #expect(selection.pokemon.map(\.id) == [94])
        selection.clear()
        #expect(selection.pokemon.isEmpty)
        #expect(!selection.isFull)
    }

    @Test func statsAreMatchedByNameInsteadOfTheirPositionInTheResponse() throws {
        let comparison = try #require(PokemonComparison(
            first: pokemon(25, stats: [("speed", 90), ("hp", 35), ("attack", 55)]),
            second: pokemon(26, stats: [("attack", 90), ("hp", 60), ("speed", 110)])))
        #expect(comparison.stats.map(\.name) == ["hp", "attack", "speed"])
        #expect(comparison.stats.map(\.firstValue) == [35, 55, 90])
        #expect(comparison.stats.map(\.secondValue) == [60, 90, 110])
        #expect(comparison.stats.first?.leadingSide == .second)
        #expect(comparison.stats.first?.difference == 25)
    }

    @Test func missingStatsAreNotReportedAsZeroOrAsAWinner() throws {
        let comparison = try #require(PokemonComparison(
            first: pokemon(25, stats: [("hp", 35), ("accuracy", 100)]),
            second: pokemon(26, stats: [("hp", 35), ("speed", 110)])))
        #expect(comparison.stats.map(\.name) == ["hp", "speed", "accuracy"])
        let speed = try #require(comparison.stats.first { $0.name == "speed" })
        #expect(speed.firstValue == nil)
        #expect(speed.secondValue == 110)
        #expect(speed.leadingSide == nil)
        #expect(speed.difference == nil)
        #expect(comparison.stats.first?.leadingSide == nil)
        #expect(comparison.stats.first?.difference == 0)
    }

    @Test func sharedScaleFitsBothPokemonAndHandlesMissingStats() throws {
        let high = try #require(PokemonComparison(
            first: pokemon(25, stats: [("hp", 255)]), second: pokemon(26)))
        #expect(high.statMaximum == 255)
        let ordinary = try #require(PokemonComparison(first: pokemon(25), second: pokemon(26)))
        #expect(ordinary.statMaximum == 150)
        let empty = try #require(PokemonComparison(first: pokemon(25, stats: []), second: pokemon(26, stats: [])))
        #expect(empty.stats.isEmpty)
        #expect(empty.statMaximum == 150)
    }
}

private enum EvolutionFixtures {
    static let root = "https://test.local/pokemon-species/1/"
    static let chainURL = "https://test.local/evolution-chain/77/"

    static func resource(_ name: String, _ url: String = "") -> [String: Any] {
        ["name": name, "url": url]
    }

    static func data(_ object: [String: Any]) throws -> Data {
        try JSONSerialization.data(withJSONObject: object)
    }

    static func decode<T: Decodable>(_ type: T.Type, _ object: [String: Any]) throws -> T {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(type, from: data(object))
    }

    static func link(_ id: Int, details: [[String: Any]] = [], children: [[String: Any]] = []) -> [String: Any] {
        ["species": resource("species-\(id)", "https://test.local/pokemon-species/\(id)/"),
         "evolution_details": details, "evolves_to": children]
    }

    static func chain(branches: Int = 2) -> [String: Any] {
        ["chain": link(1, children: (0..<branches).map { index in
            link(index + 2, details: [["trigger": resource("level-up"), "min_level": 16, "is_default": true]])
        })]
    }

    static func species(_ id: Int, hasChain: Bool = true) -> [String: Any] {
        var result: [String: Any] = [
            "flavor_text_entries": [["flavor_text": "English text.", "language": resource("en")]],
            "varieties": [
                ["is_default": false, "pokemon": resource("alternate", "https://test.local/pokemon/99999/")],
                ["is_default": true, "pokemon": resource("default", "https://test.local/pokemon/\(10000 + id)/")]
            ]
        ]
        if hasChain { result["evolution_chain"] = ["url": chainURL] }
        return result
    }

    static func detail(_ id: Int, speciesID: Int) -> [String: Any] {
        ["id": id, "name": "pokemon-\(id)", "height": 4, "weight": 60, "types": [],
         "abilities": [], "stats": [], "moves": [], "sprites": [:],
         "species": resource("species-\(speciesID)", "https://test.local/pokemon-species/\(speciesID)/")]
    }

    static func current() throws -> Pokemon {
        Pokemon(response: try decode(PokemonDetailsResponse.self, detail(999, speciesID: 1)))
    }
}

private actor EvolutionGate {
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
    func release() { releaseWaiter?.resume(); releaseWaiter = nil }
}

private actor EvolutionFixtureClient: HTTPClientProtocol {
    private(set) var urls: [String] = []
    private(set) var active = 0
    private(set) var peak = 0
    let branches: Int
    let error: APIError?
    let gate: EvolutionGate?
    let hasChain: Bool

    init(branches: Int = 2, error: APIError? = nil, gate: EvolutionGate? = nil, hasChain: Bool = true) {
        self.branches = branches
        self.error = error
        self.gate = gate
        self.hasChain = hasChain
    }

    func request<T: Decodable & Sendable>(url: URL) async throws -> T {
        urls.append(url.absoluteString)
        active += 1
        peak = max(peak, active)
        defer { active -= 1 }
        if let gate, url.pokemonID == 10002, url.path.contains("/pokemon/") { await gate.wait() }
        try await Task.sleep(for: .milliseconds(5))
        if let error { throw error }
        let object: [String: Any]
        if url.path.contains("evolution-chain") {
            object = EvolutionFixtures.chain(branches: branches)
        } else if url.path.contains("pokemon-species") {
            object = EvolutionFixtures.species(url.pokemonID!, hasChain: hasChain)
        } else {
            let id = url.pokemonID!
            object = EvolutionFixtures.detail(id, speciesID: id - 10000)
        }
        return try EvolutionFixtures.decode(T.self, object)
    }
}

struct EvolutionTests {
    @Test func treePreservesBranchesAndDefaultEvolutionMethods() throws {
        let response = try EvolutionFixtures.decode(EvolutionChainResponse.self, ["chain": EvolutionFixtures.link(
            1, children: [
                EvolutionFixtures.link(2, details: [
                    ["trigger": EvolutionFixtures.resource("level-up"), "min_level": 10, "is_default": false],
                    ["trigger": EvolutionFixtures.resource("level-up"), "min_level": 16, "is_default": true]
                ], children: [EvolutionFixtures.link(4)]),
                EvolutionFixtures.link(3)
            ])])
        let references = PokemonEvolutionFamily.references(from: response)
        #expect(references.map { $0.species.name } == ["species-1", "species-2", "species-4", "species-3"])
        #expect(references.map(\.depth) == [0, 1, 2, 1])
        #expect(references[2].parentName == "Species 2")
        #expect(references[3].parentName == "Species 1")
        #expect(references[0].conditions.isEmpty)
        #expect(references[1].conditions == ["Level 16"])
        #expect(references[3].conditions == ["Special conditions"])
    }

    @Test func alternativeConditionsStaySeparateAndSpecialRequirementsStayVisible() throws {
        let level: [String: Any] = [
            "trigger": EvolutionFixtures.resource("level-up"), "min_level": 20,
            "min_happiness": 220, "time_of_day": "night", "is_default": true
        ]
        let item: [String: Any] = [
            "trigger": EvolutionFixtures.resource("use-item"), "item": EvolutionFixtures.resource("moon-stone"),
            "region": EvolutionFixtures.resource("alola"), "required_pokemon_form": EvolutionFixtures.resource("form-a"),
            "evolved_pokemon_form": EvolutionFixtures.resource("form-b"), "is_default": true
        ]
        let response = try EvolutionFixtures.decode(EvolutionChainResponse.self, ["chain": EvolutionFixtures.link(
            1, children: [EvolutionFixtures.link(2, details: [level, level, item])])])
        let conditions = PokemonEvolutionFamily.references(from: response)[1].conditions
        #expect(conditions.count == 2)
        #expect(conditions[0] == "Level 20 · Friendship ≥ 220 · Night")
        #expect(conditions[1].contains("Use Moon Stone"))
        #expect(conditions[1].contains("In Alola"))
        #expect(conditions[1].contains("From Form A"))
        #expect(conditions[1].contains("Into Form B"))
        let special = try EvolutionFixtures.decode(EvolutionDetails.self, [
            "trigger": EvolutionFixtures.resource("level-up"),
            "condition_expression": ["expression": "internal-expression", "percentage_chance": 1]
        ])
        #expect(special.displayCondition.contains("1% chance"))
        #expect(special.displayCondition.contains("Additional conditions apply"))
        #expect(!special.displayCondition.contains("internal-expression"))
    }

    @Test func familyUsesDefaultVarietiesAndReusesCachedSpeciesAndDetails() async throws {
        let client = EvolutionFixtureClient()
        let service = PokemonService(client: client, cache: PokemonCache(directory: nil))
        let interactor = SearchInteractor(pokemonService: service)
        let current = try EvolutionFixtures.current()
        _ = try await service.fetchSpeciesDescription(url: current.speciesURL)
        let family = try #require(try await interactor.getEvolutionFamily(for: current))
        #expect(family.value.members.map { $0.pokemon.id } == [999, 10002, 10003])
        #expect(!family.isOffline)
        let firstRequests = await client.urls
        #expect(firstRequests.filter { $0 == EvolutionFixtures.root }.count == 1)
        #expect(!firstRequests.contains("https://test.local/pokemon/99999/"))
        #expect(!firstRequests.contains("https://test.local/pokemon/999/"))
        _ = try await interactor.getEvolutionFamily(for: current)
        let repeatedRequests = await client.urls
        #expect(firstRequests == repeatedRequests)
    }

    @Test func expiredMetadataAndMemberDetailsCanBeReopenedOffline() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let date = Date(timeIntervalSince1970: 1000)
        let current = try EvolutionFixtures.current()
        let onlineCache = PokemonCache(directory: directory, ttl: 60, now: { date })
        let online = SearchInteractor(pokemonService: PokemonService(client: EvolutionFixtureClient(), cache: onlineCache))
        _ = try await online.getEvolutionFamily(for: current)
        let offlineCache = PokemonCache(directory: directory, ttl: 60, now: { date.addingTimeInterval(61) })
        let offline = SearchInteractor(pokemonService: PokemonService(
            client: EvolutionFixtureClient(error: .offline), cache: offlineCache))
        let family = try #require(try await offline.getEvolutionFamily(for: current))
        #expect(family.isOffline)
        #expect(family.value.members.map { $0.pokemon.id } == [999, 10002, 10003])
        let unavailable = SearchInteractor(pokemonService: PokemonService(
            client: EvolutionFixtureClient(error: .httpStatus(500)), cache: offlineCache))
        do {
            _ = try await unavailable.getEvolutionFamily(for: current)
            Issue.record("A server error must not silently return stale data")
        } catch {
            #expect(APIError.map(error) == .httpStatus(500))
        }
    }

    @Test func familyRequestsAreBoundedAndCancellationPropagates() async throws {
        let current = try EvolutionFixtures.current()
        let client = EvolutionFixtureClient(branches: 8)
        let interactor = SearchInteractor(pokemonService: PokemonService(client: client, cache: PokemonCache(directory: nil)))
        let family = try #require(try await interactor.getEvolutionFamily(for: current))
        #expect(family.value.members.count == 9)
        let peak = await client.peak
        #expect(peak > 0 && peak <= 4)
        let gate = EvolutionGate()
        let delayed = SearchInteractor(pokemonService: PokemonService(
            client: EvolutionFixtureClient(gate: gate), cache: PokemonCache(directory: nil)))
        let task = Task { try await delayed.getEvolutionFamily(for: current) }
        await gate.waitForEntry()
        task.cancel()
        await gate.release()
        do {
            _ = try await task.value
            Issue.record("Expected cancellation to propagate")
        } catch {
            #expect(error is CancellationError)
        }
    }

    @Test func missingChainAndSpeciesWithoutEvolutionsAreHandled() async throws {
        let current = try EvolutionFixtures.current()
        let missing = SearchInteractor(pokemonService: PokemonService(
            client: EvolutionFixtureClient(hasChain: false), cache: PokemonCache(directory: nil)))
        let noInformation = try await missing.getEvolutionFamily(for: current)
        #expect(noInformation == nil)
        let single = SearchInteractor(pokemonService: PokemonService(
            client: EvolutionFixtureClient(branches: 0), cache: PokemonCache(directory: nil)))
        let family = try #require(try await single.getEvolutionFamily(for: current))
        #expect(family.value.members.count == 1)
        #expect(family.value.members.first?.pokemon.id == current.id)
    }
}
