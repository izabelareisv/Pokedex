import SwiftUI
import UIKit

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
        // Opaque colors prevent overlapping backgrounds from changing the type hue.
        // Each pair keeps white text readable in light mode and dark text readable in dark mode.
        static let onPokemonType = Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(white: 0.08, alpha: 1) : .white
        })

        static func pokemonType(_ type: PokemonType) -> Color {
            switch type {
            case .normal: typeColor(light: 0x676C58, dark: 0xB0B69E)
            case .fighting: typeColor(light: 0xB23A38, dark: 0xED8580)
            case .flying: typeColor(light: 0x7060A3, dark: 0xB5A4E3)
            case .poison: typeColor(light: 0x8E44AD, dark: 0xC58BDC)
            case .ground: typeColor(light: 0x8D6029, dark: 0xD6AD74)
            case .rock: typeColor(light: 0x7C6732, dark: 0xC1B27C)
            case .bug: typeColor(light: 0x5C721B, dark: 0xB0C96A)
            case .ghost: typeColor(light: 0x65518F, dark: 0xAD9BD7)
            case .steel: typeColor(light: 0x556D7C, dark: 0x9CB6C4)
            case .fire: typeColor(light: 0xBD3C07, dark: 0xF49A66)
            case .water: typeColor(light: 0x205EE6, dark: 0x88B4F5)
            case .grass: typeColor(light: 0x2D7836, dark: 0x87C58E)
            case .electric: typeColor(light: 0x8A6200, dark: 0xE4C351)
            case .psychic: typeColor(light: 0xB7386B, dark: 0xF095B6)
            case .ice: typeColor(light: 0x0D7484, dark: 0x7ECAD6)
            case .dragon: typeColor(light: 0x5C4ABD, dark: 0xAA9CEC)
            case .dark: typeColor(light: 0x484052, dark: 0xB2A5BC)
            case .fairy: typeColor(light: 0xAF3F7F, dark: 0xE9A1D0)
            case .stellar: typeColor(light: 0x5260B0, dark: 0x9FAAF0)
            case .unknown: typeColor(light: 0x5B6B82, dark: 0xA6B2C3)
            }
        }

        private static func typeColor(light: UInt32, dark: UInt32) -> Color {
            Color(uiColor: UIColor { traits in
                let hex = traits.userInterfaceStyle == .dark ? dark : light
                return UIColor(
                    red: CGFloat((hex >> 16) & 0xFF) / 255,
                    green: CGFloat((hex >> 8) & 0xFF) / 255,
                    blue: CGFloat(hex & 0xFF) / 255,
                    alpha: 1)
            })
        }
    }
}

struct EmptyStateIllustration: View {
    var size: CGFloat = 144

    var body: some View {
        Image("emptyStateImage")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

struct PokemonEmptyStateView: View {
    let title: String
    let message: String
    var imageSize: CGFloat = 144
    var actionTitle: String = "Try again"
    var isActionDisabled = false
    var onAction: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 12) {
            EmptyStateIllustration(size: imageSize)
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
                .accessibilityAddTraits(.isHeader)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if let onAction {
                Button(actionTitle, action: onAction)
                    .buttonStyle(.bordered)
                    .tint(DesignSystem.Colors.accent)
                    .disabled(isActionDisabled)
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding()
    }
}
