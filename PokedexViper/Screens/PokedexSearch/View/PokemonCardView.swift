import SwiftUI

struct PokemonCardView: View {
    let pokemon: Pokemon
    let isFavorite: Bool
    var isSelectingForComparison = false
    var isSelectedForComparison = false

    private var accessibilityState: String {
        var values: [String] = []
        if isFavorite { values.append("Favorite") }
        if isSelectingForComparison {
            values.append(isSelectedForComparison ? "Selected for comparison" : "Not selected")
        }
        return values.joined(separator: ", ")
    }

    var body: some View {
        VStack(spacing: DesignSystem.Dimensions.spacing / 2) {
            HStack {
                Text(pokemon.id, format: .number).foregroundStyle(.secondary)
                Spacer()
                if isFavorite { Image(systemName: "heart.fill").foregroundStyle(DesignSystem.Colors.accent) }
                if isSelectingForComparison {
                    Image(systemName: isSelectedForComparison ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelectedForComparison ? DesignSystem.Colors.accent : .secondary)
                }
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
            RoundedRectangle(cornerRadius: DesignSystem.Dimensions.cornerRadius).strokeBorder(
                isSelectedForComparison ? DesignSystem.Colors.accent : Color.secondary.opacity(0.25),
                lineWidth: isSelectedForComparison ? 2 : 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: DesignSystem.Dimensions.cornerRadius))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Pokémon \(pokemon.name), number \(pokemon.id)"))
        .accessibilityValue(accessibilityState)
        .accessibilityAddTraits(isSelectedForComparison ? .isSelected : [])
    }
}
