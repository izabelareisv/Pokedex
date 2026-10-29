import SwiftData
import SwiftUI

struct PokedexView: View {
    @State var presenter: SearchPresenter
    @State private var router = SearchRouter()
    @State private var connectivity = ConnectivityMonitor()
    @State private var searchText = ""
    @State private var selectedType: String?
    @State private var favoritesOnly = false
    @Query private var favorites: [FavoritePokemon]
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var favoriteIDs: Set<Int> { Set(favorites.map(\.pokemonID)) }
    private var filter: Filter {
        Filter(query: searchText, type: selectedType, favoritesOnly: favoritesOnly, ids: favoriteIDs)
    }
    private struct Filter: Equatable {
        let query: String
        let type: String?
        let favoritesOnly: Bool
        let ids: Set<Int>
    }

    var body: some View {
        @Bindable var router = router
        NavigationStack(path: $router.path) {
            VStack(spacing: 0) {
                header
                if presenter.isOffline || connectivity.isOffline {
                    offlineBanner
                }
                content
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Pokédex")
            .navigationDestination(for: Pokemon.self) { pokemon in
                router.destination(for: pokemon, presenter: presenter)
            }
            .task {
                connectivity.start()
                await presenter.fetchPokemonList()
            }
            .onDisappear { connectivity.stop() }
            .task(id: filter) {
                do {
                    try await Task.sleep(for: .milliseconds(300))
                    try Task.checkCancellation()
                    presenter.updateFilters(
                        query: searchText, type: selectedType,
                        favoritesOnly: favoritesOnly, favoriteIDs: favoriteIDs)
                } catch {
                    // A newer search replaces the cancelled task.
                }
            }
        }
        .tint(DesignSystem.Colors.accent)
    }

    @ViewBuilder private var offlineBanner: some View {
        if case .loaded = presenter.state {
            Label("Offline · showing saved Pokémon", systemImage: "wifi.slash").font(.callout).padding()
        } else {
            Label("Offline", systemImage: "wifi.slash").font(.callout).padding()
        }
    }

    private var header: some View {
        VStack(spacing: DesignSystem.Dimensions.spacing) {
            HStack {
                Image(systemName: "magnifyingglass").accessibilityHidden(true)
                TextField("Search loaded Pokémon", text: $searchText)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .accessibilityLabel("Search loaded Pokémon")
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .accessibilityLabel("Clear search")
                }
            }
            .padding().background(
                .background, in: RoundedRectangle(cornerRadius: DesignSystem.Dimensions.cornerRadius))
            ViewThatFits(in: .horizontal) {
                HStack {
                    typeFilter
                    favoriteFilter
                }
                VStack {
                    typeFilter
                    favoriteFilter
                }
            }
            Text("Search and filters apply to loaded pages.").font(.caption).foregroundStyle(.secondary)
        }
        .padding()
    }

    private var typeFilter: some View {
        Picker("Type", selection: $selectedType) {
            Text("All types").tag(String?.none)
            ForEach(PokemonType.allCases, id: \.self) { type in
                Text(type.title).tag(Optional(type.rawValue))
            }
        }
        .pickerStyle(.menu)
    }

    private var favoriteFilter: some View {
        Toggle("Favorites only", isOn: $favoritesOnly).toggleStyle(.button)
    }

    @ViewBuilder private var content: some View {
        switch presenter.state {
        case .idle, .loading:
            Spacer()
            ProgressView("Loading Pokémon…")
            Spacer()
        case .failed(let error):
            ContentUnavailableView {
                Label("Could not load Pokémon", systemImage: "exclamationmark.triangle")
            } description: {
                Text(error.localizedDescription)
            } actions: {
                if presenter.isLoadingPage { ProgressView("Loading Pokémon…") }
                Button("Try again") { Task { await presenter.retry() } }.disabled(presenter.isLoadingPage)
            }
        case .empty:
            ScrollView {
                ContentUnavailableView.search(text: searchText)
                footer
            }
        case .loaded(let pokemon):
            ScrollView {
                LazyVGrid(
                    columns: [
                        GridItem(
                            .adaptive(
                                minimum: dynamicTypeSize.isAccessibilitySize
                                    ? DesignSystem.Dimensions.accessibilityCardMinimumWidth
                                    : DesignSystem.Dimensions.cardMinimumWidth))
                    ], spacing: DesignSystem.Dimensions.spacing
                ) {
                    ForEach(pokemon) { item in
                        Button {
                            router.showDetails(item)
                        } label: {
                            PokemonCardView(pokemon: item, isFavorite: favoriteIDs.contains(item.id))
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Opens Pokémon details")
                        .onAppear {
                            if item.id == pokemon.last?.id && searchText.isEmpty && selectedType == nil
                                && !favoritesOnly && presenter.pageError == nil
                            {
                                Task { await presenter.loadNextPage() }
                            }
                        }
                    }
                }
                .padding()
                footer
            }
        }
    }

    private var footer: some View {
        VStack(spacing: DesignSystem.Dimensions.spacing) {
            if presenter.failedCount > 0 {
                Text("Some Pokémon could not be loaded (\(presenter.failedCount)).")
                Button("Retry missing Pokémon") { Task { await presenter.retry() } }
                    .disabled(presenter.isLoadingPage)
            } else if let error = presenter.pageError {
                Text(error.localizedDescription)
                Button("Try again") { Task { await presenter.retry() } }.disabled(presenter.isLoadingPage)
            }
            if presenter.isLoadingPage { ProgressView("Loading Pokémon…") }
            if presenter.canLoadMore {
                Button("Load more Pokémon") { Task { await presenter.loadNextPage() } }
                    .disabled(presenter.isLoadingPage)

            }
        }
        .padding()
    }
}

#Preview {
    PokedexView(
        presenter: SearchPresenter(
            interactor: SearchInteractor(pokemonService: MockPokemonService()))
    )
    .modelContainer(for: FavoritePokemon.self, inMemory: true)
}
