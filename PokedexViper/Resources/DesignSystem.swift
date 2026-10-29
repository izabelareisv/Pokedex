import SwiftUI

enum DesignSystem {
    enum Dimensions {
        static let spacing: CGFloat = 16
        static let cardMinimumWidth: CGFloat = 104
        static let accessibilityCardMinimumWidth: CGFloat = 220
        static let artworkSize: CGFloat = 80
        static let detailArtworkSize: CGFloat = 200
        static let cornerRadius: CGFloat = 16
        static let typeBadgePadding: CGFloat = 8
    }

    enum Colors {
        static let accent = Color.pokedexRed
        static let detailTintOpacity: Double = 0.12
        static let typeBadgeOpacity: Double = 0.2

        static func pokemonType(_ type: PokemonType) -> Color {
            switch type {
            case .normal, .steel, .unknown:
                .gray
            case .fighting:
                .red
            case .flying, .poison:
                .purple.opacity(0.5)
            case .ground:
                .yellow.opacity(0.5)
            case .rock:
                .brown.opacity(0.5)
            case .bug, .grass:
                .green
            case .ghost:
                .indigo
            case .fire:
                .orange
            case .water, .dragon:
                .blue
            case .electric:
                .yellow
            case .psychic, .fairy:
                .pink
            case .ice:
                .cyan
            case .dark:
                .primary
            case .stellar:
                .purple
            }
        }
    }
}
