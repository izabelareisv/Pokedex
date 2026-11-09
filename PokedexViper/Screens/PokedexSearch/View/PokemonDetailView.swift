import SwiftData
import SwiftUI

struct PokemonDetailView: View {

    let pokemon: Pokemon
    let presenter: SearchPresenter

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var favorites: [FavoritePokemon]
    @State private var description: String?
    @State private var descriptionError: APIError?
    @State private var isLoadingDescription = false
    @State private var saveFailed = false

    private var favorite: FavoritePokemon? { favorites.first { $0.pokemonID == pokemon.id } }
    private var favoriteStatus: PokemonFavoriteStatus {
        PokemonFavoriteStatus(
            pokemonID: pokemon.id,
            favoriteIDs: Set(favorites.map(\.pokemonID)))
    }
    private var color: Color { DesignSystem.Colors.pokemonType(pokemon.types.first ?? .unknown) }

    var body: some View {
        ZStack(alignment: .top) {
            // One solid background covers the header, safe areas and space around the card.
            color.ignoresSafeArea()

            ScrollView {
                VStack(spacing: -42) {
                    PokemonDetailHeaderView(pokemon: pokemon,
                                            isFavorite: favoriteStatus.isFavorite,
                                            onBack: { dismiss() },
                                            onToggleFavorite: toggleFavorite)
                    detailsCard
                }
                .overlay(alignment: .top) {
                    PokemonDetailArtworkView(imageURL: pokemon.imageURL)
                        .zIndex(1)
                }
                .padding(.bottom, 20)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $saveFailed) {
            ScrollView {
                PokemonEmptyStateView(
                    title: AppStrings.saveFavoriteTitle,
                    message: AppStrings.tryAgain,
                    actionTitle: AppStrings.ok,
                    onAction: { saveFailed = false })
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .task { await loadDescription() }
    }

    private var detailsCard: some View {
        VStack(spacing: 18) {
            PokemonAboutSection(pokemon: pokemon,
                                description: description,
                                isLoadingDescription: isLoadingDescription,
                                descriptionError: descriptionError,
                                color: color,
                                onRetry: { Task { await loadDescription() } })

            PokemonStatsSection(stats: pokemon.stats, color: color)
        }
        .padding(.horizontal, 20)
        .padding(.top, 48)
        .padding(.bottom, 24)
        .background(.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 16)
    }

    private func loadDescription() async {
        guard description == nil, !isLoadingDescription else { return }
        isLoadingDescription = true
        descriptionError = nil
        defer { isLoadingDescription = false }
        do { description = try await presenter.description(for: pokemon) } catch {
            if !Task.isCancelled { descriptionError = APIError.map(error) }
        }
    }

    private func toggleFavorite() {
        if let favorite {
            context.delete(favorite)
        } else {
            context.insert(FavoritePokemon(pokemonID: pokemon.id))
        }
        do { try context.save() } catch {
            context.rollback()
            saveFailed = true
        }
    }
}
