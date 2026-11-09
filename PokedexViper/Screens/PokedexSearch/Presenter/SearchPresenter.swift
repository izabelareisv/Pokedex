import Foundation
import Observation

enum PokemonViewState: Equatable {
    case idle
    case loading
    case loaded([Pokemon])
    case empty
    case failed(APIError)
}

enum PokemonSortOption: String, CaseIterable, Hashable, Sendable {
    case pokedex
    case hp
    case attack
    case defense
    case specialAttack
    case specialDefense
    case speed

    var title: String {
        switch self {
        case .pokedex: "Default"
        case .hp: "HP"
        case .attack: "Attack"
        case .defense: "Defense"
        case .specialAttack: "Special Attack"
        case .specialDefense: "Special Defense"
        case .speed: "Speed"
        }
    }

    var statName: String? {
        switch self {
        case .pokedex: nil
        case .hp: "hp"
        case .attack: "attack"
        case .defense: "defense"
        case .specialAttack: "special-attack"
        case .specialDefense: "special-defense"
        case .speed: "speed"
        }
    }
}

@MainActor
@Observable
final class SearchPresenter {
    private let interactor: any SearchInteractorProtocol
    private let concurrencyLimit: Int
    private let sleep: @Sendable (Duration) async throws -> Void
    private var allPokemon: [Pokemon] = []
    private var nextPage: URL?
    private var didLoadFirstPage = false
    private var failedResults: [PokemonResults] = []
    private var query = ""
    private var searchRevision = UUID()
    private var isSearchRequestInFlight = false
    private var missingQueries: Set<String> = []
    private var selectedType: String?
    private var favoritesOnly = false
    private var favoriteIDs: Set<Int> = []
    private var sortOption: PokemonSortOption = .pokedex

    private(set) var state: PokemonViewState = .idle
    private(set) var isLoadingPage = false
    private(set) var isSearching = false
    private(set) var isLoadingFavorites = false
    private(set) var favoriteError: APIError?
    private(set) var failedFavoriteCount = 0
    private(set) var searchError: APIError?
    private(set) var isOffline = false
    private(set) var pageError: APIError?
    private(set) var failedCount = 0
    var canLoadMore: Bool { nextPage != nil && !favoritesOnly }

    init(
        interactor: any SearchInteractorProtocol,
        concurrencyLimit: Int = 6,
        sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) {
        self.interactor = interactor
        self.concurrencyLimit = max(1, concurrencyLimit)
        self.sleep = sleep
    }

    func fetchPokemonList() async {
        guard !didLoadFirstPage, !isLoadingPage else { return }
        await loadPage(url: nil)
    }

    func loadNextPage() async {
        guard !favoritesOnly, let nextPage, !isLoadingPage else { return }
        await loadPage(url: nextPage)
    }

    func retry() async {
        if favoritesOnly {
            await loadFavoritesIfNeeded()
            return
        }
        if searchError != nil {
            await searchIfNeeded()
            return
        }
        guard !isLoadingPage else { return }
        if !failedResults.isEmpty {
            isLoadingPage = true
            defer { isLoadingPage = false }
            do {
                try await sleep(.seconds(3))
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

    func updateFilters(
        query: String,
        type: String?,
        favoritesOnly: Bool,
        favoriteIDs: Set<Int>,
        sortBy: PokemonSortOption = .pokedex
    ) {
        searchRevision = UUID()
        isSearchRequestInFlight = false
        isSearching = false
        isLoadingFavorites = false
        favoriteError = nil
        failedFavoriteCount = 0
        searchError = nil
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased().split(whereSeparator: \.isWhitespace).joined(separator: "-")
        self.query = Int(normalized).map { String($0) } ?? normalized
        self.selectedType = type
        self.favoritesOnly = favoritesOnly
        self.favoriteIDs = favoriteIDs
        sortOption = sortBy
        // Include the debounce in the loading state so a local miss is not shown as a final result.
        isSearching = needsRemoteSearch
        if didLoadFirstPage || !allPokemon.isEmpty || !self.query.isEmpty || favoritesOnly {
            applyFilters()
        } else if let pageError {
            state = .failed(pageError)
        } else {
            state = isLoadingPage ? .loading : .idle
        }
    }

    /// Resolve saved IDs directly instead of paging through the Pokédex to reach them.
    func loadFavoritesIfNeeded() async {
        guard favoritesOnly, !isLoadingFavorites, !Task.isCancelled else { return }
        let loadedIDs = Set(allPokemon.map(\.id))
        let missingIDs = favoriteIDs.subtracting(loadedIDs).sorted()
        guard !missingIDs.isEmpty else { return }

        let revision = searchRevision
        isLoadingFavorites = true
        favoriteError = nil
        failedFavoriteCount = 0
        applyFilters()
        defer {
            if searchRevision == revision {
                isLoadingFavorites = false
                applyFilters()
            }
        }
        let sources = missingIDs.map {
            PokemonResults(name: "", url: "https://pokeapi.co/api/v2/pokemon/\($0)/")
        }
        do {
            let batch = try await loadDetails(sources)
            try Task.checkCancellation()
            guard searchRevision == revision else { return }
            var indexed = Dictionary(uniqueKeysWithValues: allPokemon.map { ($0.id, $0) })
            isOffline = false
            for item in batch {
                switch item.result {
                case .success(let response):
                    indexed[response.value.id] = response.value
                    isOffline = isOffline || response.isOffline
                case .failure(let error):
                    failedFavoriteCount += 1
                    favoriteError = error
                    isOffline = isOffline || error == .offline
                }
            }
            allPokemon = indexed.values.sorted { $0.id < $1.id }
        } catch {
            guard searchRevision == revision, !Task.isCancelled, !(error is CancellationError) else {
                return
            }
            favoriteError = APIError.map(error)
            failedFavoriteCount = missingIDs.count
            isOffline = isOffline || favoriteError == .offline
        }
    }

    /// Called after the view's debounce; local matches never require a network lookup.
    func searchIfNeeded() async {
        guard !Task.isCancelled, !isSearchRequestInFlight else { return }
        guard needsRemoteSearch else {
            if isSearching {
                isSearching = false
                applyFilters()
            }
            return
        }

        let revision = searchRevision
        let searchedQuery = query
        searchError = nil
        isSearching = true
        isSearchRequestInFlight = true
        let loadingStarted = ContinuousClock.now
        applyFilters()
        defer {
            if searchRevision == revision {
                isSearchRequestInFlight = false
                isSearching = false
                applyFilters()
            }
        }
        // Fetch immediately, then keep the animation visible for a minimum of three seconds.
        let response: Result<ServiceValue<Pokemon>?, any Error>
        do {
            response = .success(try await interactor.findPokemon(query: searchedQuery))
        } catch {
            response = .failure(error)
        }
        do {
            let remaining = Duration.seconds(3) - loadingStarted.duration(to: .now)
            if remaining > .zero { try await sleep(remaining) }
            try Task.checkCancellation()
            let result = try response.get()
            guard searchRevision == revision else { return }
            if let result {
                if let index = allPokemon.firstIndex(where: { $0.id == result.value.id }) {
                    allPokemon[index] = result.value
                } else {
                    allPokemon.append(result.value)
                    allPokemon.sort { $0.id < $1.id }
                }
                isOffline = result.isOffline
            } else {
                missingQueries.insert(searchedQuery)
            }
        } catch {
            guard searchRevision == revision, !Task.isCancelled, !(error is CancellationError) else {
                return
            }
            let error = APIError.map(error)
            searchError = error
            isOffline = isOffline || error == .offline
        }
    }

    private var needsRemoteSearch: Bool {
        !favoritesOnly && !query.isEmpty && !missingQueries.contains(query)
            && !allPokemon.contains(where: matchesQuery)
    }

    private func matchesQuery(_ pokemon: Pokemon) -> Bool {
        query.isEmpty || pokemon.name.localizedCaseInsensitiveContains(query) || String(pokemon.id) == query
    }

    func description(for pokemon: Pokemon) async throws -> String? {
        try await interactor.getDescription(for: pokemon)
    }

    func evolutionFamily(for pokemon: Pokemon) async throws -> ServiceValue<PokemonEvolutionFamily>? {
        try await interactor.getEvolutionFamily(for: pokemon)
    }

    private func loadPage(url: URL?) async {
        isLoadingPage = true
        if !didLoadFirstPage, query.isEmpty, allPokemon.isEmpty { state = .loading }
        pageError = nil
        defer { isLoadingPage = false }
        do {
            if url != nil {
                // Show the footer animation before requesting the next page.
                try await sleep(.seconds(3))
                guard !favoritesOnly else { return }
            }
            try Task.checkCancellation()
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
        if isSearching || isLoadingFavorites {
            state = .loading
            return
        }
        if !allPokemon.contains(where: matchesQuery) {
            if let searchError {
                state = .failed(searchError)
                return
            }
        }
        if !favoritesOnly, query.isEmpty, allPokemon.isEmpty, let pageError {
            state = .failed(pageError)
            return
        }
        let filtered = allPokemon.filter {
            matchesQuery($0)
                && (selectedType == nil || $0.types.map(\.rawValue).contains(selectedType ?? ""))
                && (!favoritesOnly || favoriteIDs.contains($0.id))
        }
        let visible: [Pokemon]
        if let statName = sortOption.statName {
            visible = filtered.sorted {
                let lhs = $0.stats.first { $0.name == statName }?.value ?? 0
                let rhs = $1.stats.first { $0.name == statName }?.value ?? 0
                return lhs == rhs ? $0.id < $1.id : lhs > rhs
            }
        } else {
            visible = filtered
        }
        if visible.isEmpty, favoritesOnly, let favoriteError {
            state = .failed(favoriteError)
        } else {
            state = visible.isEmpty ? .empty : .loaded(visible)
        }
    }

    private func handleCancellationOrError(_ error: any Error) {
        if error is CancellationError || Task.isCancelled {
            if didLoadFirstPage || !query.isEmpty || !allPokemon.isEmpty || favoritesOnly {
                applyFilters()
            } else {
                state = .idle
            }
        } else {
            let error = APIError.map(error)
            isOffline = isOffline || error == .offline
            pageError = error
            if !query.isEmpty || !allPokemon.isEmpty || favoritesOnly {
                applyFilters()
            } else if !didLoadFirstPage {
                state = .failed(error)
            }
        }
    }
}
