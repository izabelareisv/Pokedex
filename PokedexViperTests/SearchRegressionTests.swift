import Foundation
import Testing

#if canImport(PokedexCore)
    @testable import PokedexCore
#else
    @testable import PokedexViper
#endif

@MainActor
struct SearchRegressionTests {
    @Test func normalizesNamesAndReusesRemoteResultsWhenSearchingByNumber() async {
        let interactor = RegressionInteractor()
        let presenter = SearchPresenter(interactor: interactor, sleep: RegressionFixtures.noDelay)
        await presenter.fetchPokemonList()
        presenter.updateFilters(query: "  POKEMON 25  ", type: nil, favoritesOnly: false, favoriteIDs: [])
        await presenter.searchIfNeeded()
        #expect(presenter.state.pokemon?.map(\.id) == [25])
        presenter.updateFilters(query: "025", type: nil, favoritesOnly: false, favoriteIDs: [])
        await presenter.searchIfNeeded()
        #expect(presenter.state.pokemon?.map(\.id) == [25])
        let queries = await interactor.remoteQueries
        #expect(queries == ["pokemon-25"])
        presenter.updateFilters(query: "", type: nil, favoritesOnly: false, favoriteIDs: [])
        #expect(presenter.state.pokemon?.map(\.id) == [1, 25])
    }

    @Test func lateRemoteResponseCannotOverwriteANewerLocalQuery() async {
        let gate = RegressionGate()
        let interactor = RegressionInteractor(remoteGate: gate, ignoreRemoteCancellation: true)
        let presenter = SearchPresenter(interactor: interactor, sleep: RegressionFixtures.noDelay)
        await presenter.fetchPokemonList()
        presenter.updateFilters(query: "pokemon-25", type: nil, favoritesOnly: false, favoriteIDs: [])
        let task = Task { await presenter.searchIfNeeded() }
        await gate.waitForEntry()
        presenter.updateFilters(query: "pokemon-1", type: nil, favoritesOnly: false, favoriteIDs: [])
        await gate.release()
        await task.value
        #expect(presenter.state.pokemon?.map(\.id) == [1])
        #expect(!presenter.isSearching)
        presenter.updateFilters(query: "", type: nil, favoritesOnly: false, favoriteIDs: [])
        #expect(presenter.state.pokemon?.map(\.id) == [1])
    }

    @Test func canceledSearchIgnoresAResponseFromANonCooperativeDependency() async {
        let gate = RegressionGate()
        let interactor = RegressionInteractor(remoteGate: gate, ignoreRemoteCancellation: true)
        let presenter = SearchPresenter(interactor: interactor, sleep: RegressionFixtures.noDelay)
        await presenter.fetchPokemonList()
        presenter.updateFilters(query: "pokemon-25", type: nil, favoritesOnly: false, favoriteIDs: [])
        let task = Task { await presenter.searchIfNeeded() }
        await gate.waitForEntry()
        task.cancel()
        await gate.release()
        await task.value
        #expect(!presenter.isSearching)
        #expect(presenter.searchError == nil)
        presenter.updateFilters(query: "", type: nil, favoritesOnly: false, favoriteIDs: [])
        #expect(presenter.state.pokemon?.map(\.id) == [1])
    }

    @Test func retryRepeatsTheSearchAndClearsTheOfflineStatusAfterOnlineRecovery() async {
        let interactor = RegressionInteractor(remoteFailure: .offline)
        let presenter = SearchPresenter(interactor: interactor, sleep: RegressionFixtures.noDelay)
        await presenter.fetchPokemonList()
        presenter.updateFilters(query: "pokemon-25", type: nil, favoritesOnly: false, favoriteIDs: [])
        await presenter.searchIfNeeded()
        #expect(presenter.state == .failed(.offline))
        #expect(presenter.isOffline)
        await interactor.recover()
        await presenter.retry()
        #expect(presenter.state.pokemon?.map(\.id) == [25])
        #expect(presenter.searchError == nil)
        #expect(!presenter.isOffline)
        let queries = await interactor.remoteQueries
        let listRequests = await interactor.listRequests
        #expect(queries == ["pokemon-25", "pokemon-25"])
        #expect(listRequests.count == 1)
    }

    @Test func confirmedMissingQueriesDoNotRepeatNetworkLookups() async {
        let interactor = RegressionInteractor()
        let presenter = SearchPresenter(interactor: interactor, sleep: RegressionFixtures.noDelay)
        await presenter.fetchPokemonList()
        presenter.updateFilters(query: "missing", type: nil, favoritesOnly: false, favoriteIDs: [])
        await presenter.searchIfNeeded()
        #expect(presenter.state == .empty)
        presenter.updateFilters(query: "missing", type: nil, favoritesOnly: false, favoriteIDs: [], sortBy: .hp)
        await presenter.searchIfNeeded()
        #expect(presenter.state == .empty)
        let queries = await interactor.remoteQueries
        #expect(queries == ["missing"])
    }

    @Test func favoritesModeDoesNotSearchForUnrelatedPokemon() async {
        let interactor = RegressionInteractor()
        let presenter = SearchPresenter(interactor: interactor, sleep: RegressionFixtures.noDelay)
        await presenter.fetchPokemonList()
        presenter.updateFilters(query: "pokemon-94", type: nil, favoritesOnly: true, favoriteIDs: [25])
        await presenter.loadFavoritesIfNeeded()
        await presenter.searchIfNeeded()
        #expect(presenter.state == .empty)
        let queries = await interactor.remoteQueries
        #expect(queries.isEmpty)
        let detailIDs = await interactor.detailIDs
        #expect(detailIDs.sorted() == [1, 25])
    }

    @Test func aFastRemoteResponseStaysLoadingUntilTheAnimationFinishes() async {
        let gate = RegressionGate()
        let delay = RegressionDelay(gate: gate)
        let interactor = RegressionInteractor()
        let presenter = SearchPresenter(interactor: interactor, sleep: { try await delay.sleep($0) })
        await presenter.fetchPokemonList()
        presenter.updateFilters(query: "pokemon-25", type: nil, favoritesOnly: false, favoriteIDs: [])
        let task = Task { await presenter.searchIfNeeded() }
        await gate.waitForEntry()
        let queries = await interactor.remoteQueries
        let durations = await delay.durations
        #expect(queries == ["pokemon-25"])
        #expect(durations.count == 1)
        #expect(durations[0] > .zero && durations[0] <= .seconds(3))
        #expect(presenter.state == .loading)
        await gate.release()
        await task.value
        #expect(presenter.state.pokemon?.map(\.id) == [25])
    }
}
