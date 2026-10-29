import Foundation
import Observation

enum PokemonViewState: Equatable {
    case idle
    case loading
    case loaded([Pokemon])
    case empty
    case failed(APIError)
}

@MainActor
@Observable
final class SearchPresenter {
    private let interactor: any SearchInteractorProtocol
    private let concurrencyLimit: Int
    private var allPokemon: [Pokemon] = []
    private var nextPage: URL?
    private var didLoadFirstPage = false
    private var failedResults: [PokemonResults] = []
    private var query = ""
    private var selectedType: String?
    private var favoritesOnly = false
    private var favoriteIDs: Set<Int> = []

    private(set) var state: PokemonViewState = .idle
    private(set) var isLoadingPage = false
    private(set) var isOffline = false
    private(set) var pageError: APIError?
    private(set) var failedCount = 0
    var canLoadMore: Bool { nextPage != nil }

    init(interactor: any SearchInteractorProtocol, concurrencyLimit: Int = 6) {
        self.interactor = interactor
        self.concurrencyLimit = max(1, concurrencyLimit)
    }

    func fetchPokemonList() async {
        guard !didLoadFirstPage, !isLoadingPage else { return }
        await loadPage(url: nil)
    }

    func loadNextPage() async {
        guard let nextPage, !isLoadingPage else { return }
        await loadPage(url: nextPage)
    }

    func retry() async {
        guard !isLoadingPage else { return }
        if !failedResults.isEmpty {
            isLoadingPage = true
            defer { isLoadingPage = false }
            do {
                let batch = try await loadDetails(failedResults)
                isOffline = false
                merge(batch)
                applyFilters()
            } catch { handleCancellationOrError(error) }
        } else if didLoadFirstPage {
            await loadNextPage()
        } else {
            await fetchPokemonList()
        }
    }

    func updateFilters(query: String, type: String?, favoritesOnly: Bool, favoriteIDs: Set<Int>) {
        self.query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        self.selectedType = type
        self.favoritesOnly = favoritesOnly
        self.favoriteIDs = favoriteIDs
        if didLoadFirstPage { applyFilters() }
    }

    func description(for pokemon: Pokemon) async throws -> String? {
        try await interactor.getDescription(for: pokemon)
    }

    private func loadPage(url: URL?) async {
        isLoadingPage = true
        if !didLoadFirstPage { state = .loading }
        pageError = nil
        defer { isLoadingPage = false }
        do {
            let page = try await interactor.getPokemonList(url: url)
            let batch = try await loadDetails(page.results)
            try Task.checkCancellation()
            nextPage = page.next
            didLoadFirstPage = true
            isOffline = page.isOffline
            merge(batch)
            applyFilters()
        } catch { handleCancellationOrError(error) }
    }

    private struct DetailResult: Sendable {
        let source: PokemonResults
        let result: Result<ServiceValue<Pokemon>, APIError>
    }

    /// Replenish one task for each completion; at most six detail requests are active.
    private func loadDetails(_ sources: [PokemonResults]) async throws -> [DetailResult] {
        let interactor = interactor
        return try await withThrowingTaskGroup(of: DetailResult.self) { group in
            var iterator = sources.makeIterator()
            func enqueue(_ source: PokemonResults) {
                group.addTask {
                    do {
                        let pokemon = try await interactor.getPokemonDetails(url: source.url)
                        try Task.checkCancellation()
                        return DetailResult(source: source, result: .success(pokemon))
                    } catch {
                        if error is CancellationError || Task.isCancelled { throw CancellationError() }
                        return DetailResult(source: source, result: .failure(APIError.map(error)))
                    }
                }
            }
            for _ in 0..<min(concurrencyLimit, sources.count) {
                if let source = iterator.next() { enqueue(source) }
            }
            var results: [DetailResult] = []
            for try await result in group {
                try Task.checkCancellation()
                results.append(result)
                if let source = iterator.next() { enqueue(source) }
            }
            return results
        }
    }

    private func merge(_ batch: [DetailResult]) {
        let retried = Set(batch.map(\.source.url))
        failedResults.removeAll { retried.contains($0.url) }
        var indexed = Dictionary(uniqueKeysWithValues: allPokemon.map { ($0.id, $0) })
        var lastError: APIError?
        for item in batch {
            switch item.result {
            case .success(let response):
                indexed[response.value.id] = response.value
                isOffline = isOffline || response.isOffline
            case .failure(let error):
                failedResults.append(item.source)
                isOffline = isOffline || error == .offline
                lastError = error
            }
        }
        allPokemon = indexed.values.sorted { $0.id < $1.id }
        failedCount = failedResults.count
        pageError = lastError
    }

    private func applyFilters() {
        if allPokemon.isEmpty, let pageError {
            state = .failed(pageError)
            return
        }
        let visible = allPokemon.filter {
            (query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) || String($0.id) == query)
                && (selectedType == nil || $0.types.map(\.rawValue).contains(selectedType ?? ""))
                && (!favoritesOnly || favoriteIDs.contains($0.id))
        }
        state = visible.isEmpty ? .empty : .loaded(visible)
    }

    private func handleCancellationOrError(_ error: any Error) {
        if error is CancellationError || Task.isCancelled {
            if didLoadFirstPage { applyFilters() } else { state = .idle }
        } else {
            let error = APIError.map(error)
            isOffline = isOffline || error == .offline
            pageError = error
            if !didLoadFirstPage { state = .failed(error) }
        }
    }
}
