import ImageIO
import SwiftData
import SwiftUI

struct PokedexView: View {
    @State var presenter: SearchPresenter
    @State private var router = SearchRouter()
    @State private var connectivity = ConnectivityMonitor()
    @State private var searchText = ""
    @State private var selectedType: String?
    @State private var selectedSort: PokemonSortOption = .pokedex
    @State private var favoritesOnly = false
    @State private var isSelectingForComparison = false
    @State private var comparisonSelection = PokemonComparisonSelection()
    @Query private var favorites: [FavoritePokemon]
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var favoriteIDs: Set<Int> { Set(favorites.map(\.pokemonID)) }
    private var filter: Filter {
        Filter(
            query: searchText,
            type: selectedType,
            favoritesOnly: favoritesOnly,
            ids: favoriteIDs,
            sortBy: selectedSort)
    }
    private struct Filter: Equatable {
        let query: String
        let type: String?
        let favoritesOnly: Bool
        let ids: Set<Int>
        let sortBy: PokemonSortOption
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
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if isSelectingForComparison { comparisonBar }
            }
            .navigationTitle("Pokédex")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isSelectingForComparison.toggle()
                        if !isSelectingForComparison { comparisonSelection.clear() }
                    } label: {
                        if isSelectingForComparison {
                            Text("Cancel")
                        } else {
                            Label("Compare", systemImage: "rectangle.split.2x1")
                                .labelStyle(.titleAndIcon)
                        }
                    }
                    .accessibilityHint(isSelectingForComparison
                        ? "Cancels comparison selection"
                        : "Select two Pokémon to compare their stats, types and abilities")
                }
            }
            .navigationDestination(for: SearchRouter.Route.self) { route in
                router.destination(for: route, presenter: presenter)
            }
            .task {
                connectivity.start()
                await presenter.fetchPokemonList()
            }
            .onDisappear { connectivity.stop() }
            .task(id: filter) {
                guard !Task.isCancelled else { return }
                presenter.updateFilters(
                    query: searchText, type: selectedType,
                    favoritesOnly: favoritesOnly, favoriteIDs: favoriteIDs,
                    sortBy: selectedSort)
                await presenter.loadFavoritesIfNeeded()
                do {
                    try await Task.sleep(for: .milliseconds(300))
                    try Task.checkCancellation()
                    await presenter.searchIfNeeded()
                } catch {
                    // A newer search replaces the cancelled task.
                }
            }
        }
        .tint(DesignSystem.Colors.accent)
    }

    private var comparisonBar: some View {
        VStack(spacing: 10) {
            Text("Select 2 Pokémon to compare (\(comparisonSelection.pokemon.count)/2)")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                ForEach(0..<2, id: \.self) { index in
                    comparisonSlot(index: index)
                }
            }
            Button {
                if let comparison = comparisonSelection.comparison {
                    router.showComparison(comparison)
                }
            } label: {
                Text("Compare Pokémon")
                    .frame(maxWidth: .infinity, minHeight: 32)
            }
            .buttonStyle(.borderedProminent)
            .disabled(comparisonSelection.comparison == nil)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(.regularMaterial)
    }

    @ViewBuilder private func comparisonSlot(index: Int) -> some View {
        if comparisonSelection.pokemon.indices.contains(index) {
            let pokemon = comparisonSelection.pokemon[index]
            Button {
                comparisonSelection.remove(id: pokemon.id)
            } label: {
                HStack(spacing: 8) {
                    Text(pokemon.name)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Spacer(minLength: 0)
                    Image(systemName: "xmark.circle.fill")
                }
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(DesignSystem.Colors.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(pokemon.name) from comparison")
        } else {
            Text("Pokémon \(index + 1)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 44)
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(.secondary.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4]))
                }
                .accessibilityLabel("Select Pokémon \(index + 1)")
        }
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
                TextField("Search Pokémon", text: $searchText)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .accessibilityLabel("Search Pokémon")
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
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 10) {
                    typeFilter
                    sortFilter
                    favoriteFilter
                }
            } else {
                HStack(spacing: 8) {
                    typeFilter
                    sortFilter
                    favoriteFilter
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                resultsSummary
            }
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
    }

    private var selectedPokemonType: PokemonType? {
        selectedType.flatMap(PokemonType.init(rawValue:))
    }

    private var typeFilter: some View {
        Menu {
            Picker("Type", selection: $selectedType) {
                Text("All types").tag(String?.none)
                ForEach(PokemonType.allCases, id: \.self) { type in
                    Text(type.title).tag(Optional(type.rawValue))
                }
            }
        } label: {
            FilterPill(
                title: selectedPokemonType?.title ?? "Type",
                showsChevron: true,
                isActive: selectedType != nil,
                tint: selectedPokemonType.map(DesignSystem.Colors.pokemonType) ?? DesignSystem.Colors.accent)
        }
        .accessibilityLabel("Type")
        .accessibilityValue(selectedPokemonType?.title ?? "All types")
    }

    private var favoriteFilter: some View {
        Button {
            favoritesOnly.toggle()
        } label: {
            FilterPill(
                title: "Favorites",
                symbol: favoritesOnly ? "heart.fill" : "heart",
                isActive: favoritesOnly)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Favorites only")
        .accessibilityValue(favoritesOnly ? Text("On") : Text("Off"))
        .accessibilityAddTraits(favoritesOnly ? .isSelected : [])
    }

    private var sortFilter: some View {
        Menu {
            Picker(AppStrings.sortBy, selection: $selectedSort) {
                ForEach(PokemonSortOption.allCases, id: \.self) { option in
                    Text(option.title).tag(option)
                }
            }
        } label: {
            FilterPill(
                title: selectedSort.title,
                showsChevron: true,
                isActive: selectedSort != .pokedex,
                titleLineLimit: 2)
        }
        .accessibilityLabel(AppStrings.sortBy)
        .accessibilityValue(selectedSort.title)
    }

    @ViewBuilder private var resultsSummary: some View {
        switch presenter.state {
        case .loaded(let pokemon):
            summary(count: pokemon.count)
        case .empty:
            summary(count: 0)
        default:
            EmptyView()
        }
    }

    private func summary(count: Int) -> some View {
        Text("\(count) Pokémon")
            .font(.subheadline)
    }

    @ViewBuilder private var content: some View {
        switch presenter.state {
        case .idle, .loading:
            Spacer()
            if presenter.isSearching {
                PikachuLoadingView()
            } else {
                ProgressView(presenter.isLoadingFavorites ? "Loading favorites…" : "Loading Pokémon…")
            }
            Spacer()
        case .failed(let error):
            ScrollView {
                VStack(spacing: DesignSystem.Dimensions.spacing) {
                    PokemonEmptyStateView(
                        title: favoritesOnly ? "Could not load favorites"
                            : presenter.searchError == nil ? "Could not load Pokémon" : "Could not search Pokémon",
                        message: error.localizedDescription,
                        isActionDisabled: presenter.isLoadingFavorites || (!favoritesOnly && presenter.isLoadingPage),
                        onAction: { Task { await presenter.retry() } })
                    if presenter.isLoadingPage && !favoritesOnly {
                        PikachuLoadingView(title: "Loading Pokémon…", imageWidth: 100)
                    }
                }
            }
        case .empty:
            ScrollView {
                if favoritesOnly && favoriteIDs.isEmpty {
                    PokemonEmptyStateView(
                        title: "No favorites yet",
                        message: "Tap the heart on a Pokémon to save it here.")
                } else {
                    PokemonEmptyStateView(
                        title: "No Pokémon found",
                        message: searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? "Try changing your filters."
                            : "No Pokémon match “\(searchText)” with the current filters.",
                        imageSize: 100)
                }
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
                            if isSelectingForComparison {
                                comparisonSelection.toggle(item)
                            } else {
                                router.showDetails(item)
                            }
                        } label: {
                            PokemonCardView(
                                pokemon: item,
                                isFavorite: favoriteIDs.contains(item.id),
                                isSelectingForComparison: isSelectingForComparison,
                                isSelectedForComparison: comparisonSelection.contains(item))
                        }
                        .buttonStyle(.plain)
                        .disabled(isSelectingForComparison && comparisonSelection.isFull && !comparisonSelection.contains(item))
                        .accessibilityHint(isSelectingForComparison ? "Toggles selection for comparison" : "Opens Pokémon details")
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

    @ViewBuilder private var footer: some View {
        if favoritesOnly {
            if let error = presenter.favoriteError {
                PokemonEmptyStateView(
                    title: "Some favorites could not be loaded (\(presenter.failedFavoriteCount)).",
                    message: error.localizedDescription,
                    imageSize: 88,
                    actionTitle: "Retry favorites",
                    isActionDisabled: presenter.isLoadingFavorites,
                    onAction: { Task { await presenter.retry() } })
            }
        } else if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || presenter.failedCount > 0 || presenter.pageError != nil
        {
            paginationFooter
        }
    }

    private var paginationFooter: some View {
        VStack(spacing: DesignSystem.Dimensions.spacing) {
            if presenter.failedCount > 0 {
                PokemonEmptyStateView(
                    title: "Some Pokémon could not be loaded (\(presenter.failedCount)).",
                    message: presenter.pageError?.localizedDescription ?? "Please try again.",
                    imageSize: 88,
                    actionTitle: "Retry missing Pokémon",
                    isActionDisabled: presenter.isLoadingPage,
                    onAction: { Task { await presenter.retry() } })
            } else if let error = presenter.pageError {
                PokemonEmptyStateView(
                    title: "Could not load more Pokémon",
                    message: error.localizedDescription,
                    imageSize: 88,
                    isActionDisabled: presenter.isLoadingPage,
                    onAction: { Task { await presenter.retry() } })
            }
            if presenter.isLoadingPage {
                PikachuLoadingView(title: "Loading Pokémon…", imageWidth: 100)
            } else if presenter.canLoadMore, searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button("Load more Pokémon") { Task { await presenter.loadNextPage() } }
            }
        }
        .padding()
    }
}

private struct FilterPill: View {
    let title: String
    var symbol: String? = nil
    var showsChevron = false
    var isActive = false
    var tint: Color = DesignSystem.Colors.accent
    var titleLineLimit = 1

    var body: some View {
        HStack(spacing: 5) {
            if let symbol {
                Image(systemName: symbol)
                    .accessibilityHidden(true)
            }
            Text(title)
                .lineLimit(titleLineLimit)
                .multilineTextAlignment(.center)
            if showsChevron {
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .accessibilityHidden(true)
            }
        }
        .font(.subheadline)
        .minimumScaleFactor(0.8)
        .foregroundStyle(isActive ? tint : DesignSystem.Colors.accent)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, minHeight: 44)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(isActive ? tint.opacity(0.12) : Color(.secondarySystemGroupedBackground))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(isActive ? .clear : Color(.separator).opacity(0.4), lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 16))
    }
}

private struct PikachuLoadingView: View {
    var title = "Searching Pokémon…"
    var imageWidth: CGFloat = 160
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 12) {
            RunningPikachuImage(isAnimating: !reduceMotion)
                .frame(width: imageWidth, height: imageWidth * 357 / 500)
                .accessibilityHidden(true)
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
    }
}

@MainActor
private struct RunningPikachuImage: UIViewRepresentable {
    let isAnimating: Bool

    private static let animation: (frames: [UIImage], duration: TimeInterval) = {
        guard let url = Bundle.main.url(forResource: "pikachuRunning", withExtension: "gif"),
            let source = CGImageSourceCreateWithURL(url as CFURL, nil)
        else { return ([], 0) }

        var frames: [UIImage] = []
        var duration: TimeInterval = 0
        for index in 0..<CGImageSourceGetCount(source) {
            guard let frame = CGImageSourceCreateImageAtIndex(source, index, nil) else { continue }
            frames.append(UIImage(cgImage: frame))
            let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any]
            let gif = properties?[kCGImagePropertyGIFDictionary] as? [CFString: Any]
            let delay = gif?[kCGImagePropertyGIFUnclampedDelayTime] as? Double
                ?? gif?[kCGImagePropertyGIFDelayTime] as? Double ?? 0.1
            duration += max(delay, 0.02)
        }
        return (frames, duration)
    }()

    func makeUIView(context: Context) -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.image = Self.animation.frames.first
        imageView.animationImages = Self.animation.frames
        imageView.animationDuration = Self.animation.duration
        imageView.animationRepeatCount = 0
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        return imageView
    }

    func updateUIView(_ imageView: UIImageView, context: Context) {
        if isAnimating, !imageView.isAnimating {
            imageView.startAnimating()
        } else if !isAnimating {
            imageView.stopAnimating()
        }
    }

    static func dismantleUIView(_ imageView: UIImageView, coordinator: ()) {
        imageView.stopAnimating()
    }
}

#Preview {
    PokedexView(
        presenter: SearchPresenter(
            interactor: SearchInteractor(pokemonService: MockPokemonService()))
    )
    .modelContainer(for: FavoritePokemon.self, inMemory: true)
}
