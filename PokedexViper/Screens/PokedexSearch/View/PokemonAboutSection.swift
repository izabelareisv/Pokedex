import SwiftUI

struct PokemonAboutSection: View {
    let pokemon: Pokemon
    let description: String?
    let isLoadingDescription: Bool
    let descriptionError: APIError?
    let color: Color
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            typeBadges

            Text("About")
                .font(.headline)
                .foregroundStyle(color)

            measurements
            Rectangle().fill(Color.secondary.opacity(0.15)).frame(height: 1)
            descriptionContent
                .frame(minHeight: 42, alignment: .leading)
        }
    }

    private var typeBadges: some View {
        HStack(spacing: 8) {
            ForEach(pokemon.types, id: \.self) { type in
                Text(type.title)
                    .font(.caption.bold())
                    .foregroundStyle(DesignSystem.Colors.onPokemonType)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(DesignSystem.Colors.pokemonType(type), in: Capsule())
            }
        }
    }

    private var measurements: some View {
        HStack(alignment: .top, spacing: 0) {
            MeasurementItem(icon: "scalemass", value: pokemon.formattedWeight, title: "Weight")
            MeasurementItem(icon: "ruler", value: pokemon.formattedHeight, title: "Height")
            MeasurementItem(
                icon: "sparkles",
                value: pokemon.abilities.joined(separator: ", "),
                title: "Abilities",
                showsDivider: false)
        }
    }

    @ViewBuilder private var descriptionContent: some View {
        if isLoadingDescription {
            ProgressView("Loading description…")
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if let description {
            Text(description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if let descriptionError {
            PokemonEmptyStateView(
                title: "Could not load description",
                message: descriptionError.localizedDescription,
                imageSize: 88,
                actionTitle: "Retry description",
                onAction: onRetry)
        }
    }
}

private struct MeasurementItem: View {
    let icon: String
    let value: String
    let title: LocalizedStringKey
    var showsDivider = true

    var body: some View {
        VStack(spacing: 7) {
            HStack(alignment: .top, spacing: 5) {
                Image(systemName: icon).font(.caption)
                Text(value)
                    .font(.caption2)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity, minHeight: 30)

            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 5)
        .overlay(alignment: .trailing) {
            if showsDivider {
                Rectangle().fill(Color.secondary.opacity(0.18))
                    .frame(width: 1, height: 38)
                    .offset(x: 2)
            }
        }
    }
}
