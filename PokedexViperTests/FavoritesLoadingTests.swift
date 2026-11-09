import Foundation
import Testing

#if canImport(PokedexCore)
    @testable import PokedexCore
#else
    @testable import PokedexViper
#endif

@MainActor
struct FavoritesLoadingTests {
    @Test func loadsEverySavedIDWithoutAdvancingPaginationOrRepeatingLoadedDetails() async throws {
        let interactor = RegressionInteractor()
        let presenter = SearchPresenter(interactor: interactor, sleep: RegressionFixtures.noDelay)
        await presenter.fetchPokemonList()
        presenter.updateFilters(query: "", type: nil, favoritesOnly: true, favoriteIDs: [1, 25, 94])
        await presenter.loadFavoritesIfNeeded()
        let visible = try #require(presenter.state.pokemon)
        #expect(visible.map(\.id) == [1, 25, 94])
        #expect(!presenter.canLoadMore)
        await presenter.loadNextPage()
        let listRequests = await interactor.listRequests
        let firstDetails = await interactor.detailIDs
        #expect(listRequests.count == 1)
        #expect(firstDetails.sorted() == [1, 25, 94])
        await presenter.loadFavoritesIfNeeded()
        let repeatedDetails = await interactor.detailIDs
        #expect(repeatedDetails == firstDetails)
        presenter.updateFilters(query: "", type: nil, favoritesOnly: false, favoriteIDs: [1, 25, 94])
        #expect(presenter.canLoadMore)
    }

    @Test func searchTypeAndSortingApplyToFavoritesOutsideLoadedPages() async throws {
        let interactor = RegressionInteractor(hpValues: [25: 100, 94: 100])
        let presenter = SearchPresenter(interactor: interactor, sleep: RegressionFixtures.noDelay)
        await presenter.fetchPokemonList()
        presenter.updateFilters(query: "", type: nil, favoritesOnly: true, favoriteIDs: [1, 25, 94], sortBy: .hp)
        await presenter.loadFavoritesIfNeeded()
        #expect(presenter.state.pokemon?.map(\.id) == [25, 94, 1])
        presenter.updateFilters(query: "", type: "ghost", favoritesOnly: true, favoriteIDs: [1, 25, 94])
        #expect(presenter.state.pokemon?.map(\.id) == [94])
        presenter.updateFilters(query: "25", type: nil, favoritesOnly: true, favoriteIDs: [1, 25, 94])
        await presenter.loadFavoritesIfNeeded()
        await presenter.searchIfNeeded()
        #expect(presenter.state.pokemon?.map(\.id) == [25])
        let remoteQueries = await interactor.remoteQueries
        #expect(remoteQueries.isEmpty)
    }

    @Test func partialFailureKeepsFavoritesAndRetriesOnlyMissingIDs() async throws {
        let interactor = RegressionInteractor(failedIDs: [25])
        let presenter = SearchPresenter(interactor: interactor, sleep: RegressionFixtures.noDelay)
        await presenter.fetchPokemonList()
        presenter.updateFilters(query: "", type: nil, favoritesOnly: true, favoriteIDs: [25, 94])
        await presenter.loadFavoritesIfNeeded()
        #expect(presenter.state.pokemon?.map(\.id) == [94])
        #expect(presenter.failedFavoriteCount == 1)
        #expect(presenter.favoriteError == .offline)
        await interactor.recover()
        await presenter.retry()
        #expect(presenter.state.pokemon?.map(\.id) == [25, 94])
        #expect(presenter.favoriteError == nil)
        #expect(presenter.failedFavoriteCount == 0)
        #expect(!presenter.isOffline)
        let detailIDs = await interactor.detailIDs
        #expect(detailIDs.filter { $0 == 25 }.count == 2)
        #expect(detailIDs.filter { $0 == 94 }.count == 1)
    }

    @Test func emptyFavoritesStayEmptyEvenWhenTheGeneralListFails() async {
        let interactor = RegressionInteractor(initialFailure: .offline)
        let presenter = SearchPresenter(interactor: interactor, sleep: RegressionFixtures.noDelay)
        presenter.updateFilters(query: "", type: nil, favoritesOnly: true, favoriteIDs: [])
        await presenter.fetchPokemonList()
        await presenter.loadFavoritesIfNeeded()
        #expect(presenter.state == .empty)
        #expect(presenter.favoriteError == nil)
        let detailIDs = await interactor.detailIDs
        #expect(detailIDs.isEmpty)
    }

    @Test func removedFavoritesDoNotMergeLateResponses() async {
        let gate = RegressionGate()
        let interactor = RegressionInteractor(detailGate: gate)
        let presenter = SearchPresenter(interactor: interactor, sleep: RegressionFixtures.noDelay)
        await presenter.fetchPokemonList()
        presenter.updateFilters(query: "", type: nil, favoritesOnly: true, favoriteIDs: [25])
        let task = Task { await presenter.loadFavoritesIfNeeded() }
        await gate.waitForEntry()
        #expect(presenter.state == .loading)
        presenter.updateFilters(query: "", type: nil, favoritesOnly: true, favoriteIDs: [])
        await gate.release()
        await task.value
        #expect(presenter.state == .empty)
        #expect(!presenter.isLoadingFavorites)
        presenter.updateFilters(query: "", type: nil, favoritesOnly: false, favoriteIDs: [])
        #expect(presenter.state.pokemon?.map(\.id) == [1])
    }

    @Test func favoriteRequestsRespectConcurrencyAndRecoverFromTotalFailure() async {
        let many = RegressionInteractor()
        let presenter = SearchPresenter(interactor: many, concurrencyLimit: 3, sleep: RegressionFixtures.noDelay)
        presenter.updateFilters(query: "", type: nil, favoritesOnly: true, favoriteIDs: Set(1...20))
        await presenter.loadFavoritesIfNeeded()
        #expect(presenter.state.pokemon?.map(\.id) == Array(1...20))
        let peak = await many.peak
        #expect(peak > 0 && peak <= 3)

        let failing = RegressionInteractor(failedIDs: [25])
        let failure = SearchPresenter(interactor: failing, sleep: RegressionFixtures.noDelay)
        failure.updateFilters(query: "", type: nil, favoritesOnly: true, favoriteIDs: [25])
        await failure.loadFavoritesIfNeeded()
        #expect(failure.state == .failed(.offline))
        #expect(!failure.isLoadingFavorites)
        await failing.recover()
        await failure.retry()
        #expect(failure.state.pokemon?.map(\.id) == [25])
    }
}
