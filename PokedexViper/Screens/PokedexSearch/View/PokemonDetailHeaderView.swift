import SwiftUI

struct PokemonDetailHeaderView: View {
    let pokemon: Pokemon
    let isFavorite: Bool
    let onBack: () -> Void
    let onToggleFavorite: () -> Void

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                Image("pokeballBackgroundCard")
                    .renderingMode(.template)
                    .resizable()
                    .foregroundStyle(DesignSystem.Colors.onPokemonType.opacity(0.12))
                    .scaledToFit()
                    .frame(width: 208, height: 208)
                    .offset(x: proxy.size.width * 0.25, y: 20)
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)
                    .zIndex(1)

                VStack(spacing: 0) {
                    navigationRow
                    Spacer()
                }
                .zIndex(2)
            }
            .frame(height: 310)
            .clipShape(Rectangle())
        }
        .frame(height: 310)
    }

    private var navigationRow: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 19, weight: .medium))
                    .frame(width: 36, height: 36, alignment: .leading)
            }
            .accessibilityLabel("Back")
            
            Text(pokemon.name)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .lineLimit(1)
            
            Spacer(minLength: 8)
            
            Text(String(format: "#%03d", pokemon.id))
                .font(.caption.bold())
                .monospacedDigit()
            
            Button {
                onToggleFavorite()
            } label: {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 36, height: 36)
            }
            .accessibilityLabel(isFavorite ? Text("Remove from favorites") : Text("Add to favorites"))
        }
        .foregroundStyle(DesignSystem.Colors.onPokemonType)
        .padding(.horizontal, 18)
        .padding(.top, 8)
    }
}
