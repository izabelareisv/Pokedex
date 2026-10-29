import SwiftUI

struct PokemonCardView: View {
    let pokemon: Pokemon
    let isFavorite: Bool

    var body: some View {
        VStack(spacing: DesignSystem.Dimensions.spacing / 2) {
            HStack {
                Text(pokemon.id, format: .number).foregroundStyle(.secondary)
                Spacer()
                if isFavorite { Image(systemName: "heart.fill").foregroundStyle(DesignSystem.Colors.accent) }
            }
            .font(.caption)
            CachedPokemonImage(url: pokemon.imageURL)
                .frame(height: DesignSystem.Dimensions.artworkSize)
            Text(pokemon.name).font(.headline).foregroundStyle(.primary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background, in: RoundedRectangle(cornerRadius: DesignSystem.Dimensions.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Dimensions.cornerRadius).stroke(
                .secondary.opacity(0.25))
        )
        .contentShape(RoundedRectangle(cornerRadius: DesignSystem.Dimensions.cornerRadius))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Pokémon \(pokemon.name), number \(pokemon.id)"))
        .accessibilityValue(isFavorite ? Text("Favorite") : Text(""))
    }
}
