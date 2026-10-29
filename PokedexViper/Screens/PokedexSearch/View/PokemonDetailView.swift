import SwiftData
import SwiftUI

struct PokemonDetailView: View {
    let pokemon: Pokemon
    let presenter: SearchPresenter
    @Environment(\.modelContext) private var context
    @Query private var favorites: [FavoritePokemon]
    @State private var description: String?
    @State private var descriptionError: APIError?
    @State private var isLoadingDescription = false
    @State private var saveFailed = false

    private var favorite: FavoritePokemon? { favorites.first { $0.pokemonID == pokemon.id } }
    private var color: Color { DesignSystem.Colors.pokemonType(pokemon.types.first ?? .unknown) }

    var body: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Dimensions.spacing) {
                CachedPokemonImage(url: pokemon.imageURL).frame(
                    height: DesignSystem.Dimensions.detailArtworkSize)
                ViewThatFits {
                    HStack { typeBadges }
                    VStack { typeBadges }
                }
                Text("About").font(.title2).bold()
                ViewThatFits {
                    HStack(spacing: DesignSystem.Dimensions.spacing) { measurements }
                    VStack(spacing: DesignSystem.Dimensions.spacing) { measurements }
                }
                if !pokemon.moves.isEmpty {
                    Text("Moves").font(.headline)
                    Text(pokemon.moves.joined(separator: ", "))
                }
                if isLoadingDescription { ProgressView("Loading description…") }
                if let description { Text(description).frame(maxWidth: .infinity, alignment: .leading) }
                if let descriptionError {
                    Text(descriptionError.localizedDescription).foregroundStyle(.secondary)
                    Button("Retry description") { Task { await loadDescription() } }
                }
                Text("Base Stats").font(.title2).bold()
                ForEach(pokemon.stats, id: \.name) { stat in
                    VStack(alignment: .leading) {
                        HStack {
                            Text(stat.title)
                            Spacer()
                            Text(stat.value, format: .number)
                        }
                        ProgressView(value: stat.fraction).tint(color)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text("\(stat.title): \(stat.value)"))
                }
            }
            .padding()
        }
        .background(color.opacity(DesignSystem.Colors.detailTintOpacity))
        .navigationTitle(pokemon.name)
        .toolbar {
            Button {
                toggleFavorite()
            } label: {
                Image(systemName: favorite == nil ? "heart" : "heart.fill")
            }
            .accessibilityLabel(favorite == nil ? Text("Add to favorites") : Text("Remove from favorites"))
        }
        .alert("Could not save favorite", isPresented: $saveFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Please try again.")
        }
        .task { await loadDescription() }
    }

    private var typeBadges: some View {
        ForEach(pokemon.types, id: \.self) { type in
            Text(type.title)
                .font(.headline).padding(DesignSystem.Dimensions.typeBadgePadding)
                .background(
                    DesignSystem.Colors.pokemonType(type).opacity(DesignSystem.Colors.typeBadgeOpacity),
                    in: Capsule())
        }
    }

    private var measurements: some View {
        Group {
            Label {
                Text("Weight: \(pokemon.formattedWeight)")
            } icon: {
                Image(systemName: "scalemass")
            }
            Label {
                Text("Height: \(pokemon.formattedHeight)")
            } icon: {
                Image(systemName: "ruler")
            }
        }
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
