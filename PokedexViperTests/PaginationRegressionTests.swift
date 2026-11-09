import Foundation
import Testing

#if canImport(PokedexCore)
    @testable import PokedexCore
#else
    @testable import PokedexViper
#endif

@MainActor
struct PaginationRegressionTests {
    @Test func waitsThreeSecondsBeforeRequestAndIgnoresDuplicateLoadActions() async {
        let gate = RegressionGate()
        let delay = RegressionDelay(gate: gate)
        let interactor = RegressionInteractor()
        let presenter = SearchPresenter(interactor: interactor, sleep: { try await delay.sleep($0) })
        await presenter.fetchPokemonList()
        let task = Task { await presenter.loadNextPage() }
        await gate.waitForEntry()
        #expect(presenter.isLoadingPage)
        let beforeRequest = await interactor.listRequests
        let durations = await delay.durations
        #expect(beforeRequest.count == 1)
        #expect(durations == [.seconds(3)])
        await presenter.loadNextPage()
        #expect(presenter.isLoadingPage)
        await gate.release()
        await task.value
        let afterRequest = await interactor.listRequests
        #expect(afterRequest.count == 2)
        #expect(presenter.state.pokemon?.map(\.id) == [1, 25, 94])
        #expect(!presenter.isLoadingPage)
    }

    @Test func cancellingDuringTheAnimationPreventsTheRequest() async {
        let gate = RegressionGate()
        let delay = RegressionDelay(gate: gate)
        let interactor = RegressionInteractor()
        let presenter = SearchPresenter(interactor: interactor, sleep: { try await delay.sleep($0) })
        await presenter.fetchPokemonList()
        let task = Task { await presenter.loadNextPage() }
        await gate.waitForEntry()
        task.cancel()
        await gate.release()
        await task.value
        let requests = await interactor.listRequests
        #expect(requests.count == 1)
        #expect(!presenter.isLoadingPage)
        #expect(presenter.pageError == nil)
        #expect(presenter.canLoadMore)
        #expect(presenter.state.pokemon?.map(\.id) == [1])
    }

    @Test func switchingToFavoritesCancelsPendingPaginationWithoutLosingTheCursor() async {
        let gate = RegressionGate()
        let delay = RegressionDelay(gate: gate)
        let interactor = RegressionInteractor()
        let presenter = SearchPresenter(interactor: interactor, sleep: { try await delay.sleep($0) })
        await presenter.fetchPokemonList()
        let task = Task { await presenter.loadNextPage() }
        await gate.waitForEntry()
        presenter.updateFilters(query: "", type: nil, favoritesOnly: true, favoriteIDs: [1])
        await gate.release()
        await task.value
        let requests = await interactor.listRequests
        #expect(requests.count == 1)
        #expect(!presenter.canLoadMore)
        presenter.updateFilters(query: "", type: nil, favoritesOnly: false, favoriteIDs: [1])
        #expect(presenter.canLoadMore)
    }

    @Test func pageFailurePreservesResultsAndRetriesTheSamePage() async {
        let interactor = RegressionInteractor(pageFailure: .httpStatus(500))
        let presenter = SearchPresenter(interactor: interactor, sleep: RegressionFixtures.noDelay)
        await presenter.fetchPokemonList()
        await presenter.loadNextPage()
        #expect(presenter.pageError == .httpStatus(500))
        #expect(presenter.state.pokemon?.map(\.id) == [1])
        #expect(!presenter.isLoadingPage)
        await interactor.recover()
        await presenter.retry()
        let requests = await interactor.listRequests
        #expect(requests.count == 3)
        #expect(requests[1] == RegressionFixtures.nextPage)
        #expect(requests[2] == RegressionFixtures.nextPage)
        #expect(presenter.state.pokemon?.map(\.id) == [1, 25, 94])
        #expect(presenter.pageError == nil)
    }

    @Test func laterPagesDoNotDuplicatePokemonLoadedBySearch() async {
        let interactor = RegressionInteractor()
        let presenter = SearchPresenter(interactor: interactor, sleep: RegressionFixtures.noDelay)
        await presenter.fetchPokemonList()
        presenter.updateFilters(query: "pokemon-25", type: nil, favoritesOnly: false, favoriteIDs: [])
        await presenter.searchIfNeeded()
        presenter.updateFilters(query: "", type: nil, favoritesOnly: false, favoriteIDs: [])
        await presenter.loadNextPage()
        #expect(presenter.state.pokemon?.map(\.id) == [1, 25, 94])
    }
}
