import SwiftUI

struct CachedPokemonImage: View {
    let url: URL?
    @State private var image: UIImage?
    @State private var failed = false

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFit()
            } else if failed || url == nil {
                Image(systemName: "photo").resizable().scaledToFit().padding()
            } else {
                ProgressView()
            }
        }
        .accessibilityHidden(true)
        .task(id: url) {
            image = nil
            failed = false
            guard let url else { return }
            do {
                let data = try await PokemonImageLoader.shared.data(for: url)
                try Task.checkCancellation()
                image = UIImage(data: data)
                failed = image == nil
            } catch {
                if !Task.isCancelled { failed = true }
            }
        }
    }
}
