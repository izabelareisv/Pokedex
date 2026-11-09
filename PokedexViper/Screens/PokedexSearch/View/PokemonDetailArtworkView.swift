import SwiftUI

struct PokemonDetailArtworkView: View {
    let imageURL: URL?

    var body: some View {
        GeometryReader { proxy in
            CachedPokemonImage(url: imageURL)
                .frame(width: min(proxy.size.width * 0.62, 250), height: 205)
                .shadow(color: .black.opacity(0.12), radius: 8, y: 5)
                .position(x: proxy.size.width / 2, y: 207)
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}
