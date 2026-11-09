import SwiftUI

struct CachedPokemonImage: View {
    let url: URL?
    @State private var image: UIImage?
    @State private var failed = false

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFit()
                    .accessibilityHidden(true)
            } else if failed || url == nil {
                VStack(spacing: 4) {
                    EmptyStateIllustration(size: 48)
                    Text("Image unavailable")
                        .font(.caption2)
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ProgressView()
            }
        }
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
