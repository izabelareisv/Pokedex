import SwiftUI

struct PokemonComparisonView: View {
    let comparison: PokemonComparison

    private var firstColor: Color {
        DesignSystem.Colors.pokemonType(comparison.first.types.first ?? .unknown)
    }
    private var secondColor: Color {
        DesignSystem.Colors.pokemonType(comparison.second.types.first ?? .unknown)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                HStack(alignment: .top, spacing: 12) {
                    PokemonComparisonSummary(pokemon: comparison.first)
                    PokemonComparisonSummary(pokemon: comparison.second)
                }
                statsSection
                aboutSection
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Compare")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Base Stats")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            ForEach(comparison.stats) { stat in
                statRow(stat)
            }
            if comparison.stats.isEmpty {
                Text("No base stats available.")
                    .foregroundStyle(.secondary)
            }
            Text("Higher values are highlighted. Base stats do not include level or training.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
    }

    private func statRow(_ stat: ComparedPokemonStat) -> some View {
        VStack(spacing: 8) {
            Text(stat.title)
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity)
            HStack(alignment: .firstTextBaseline) {
                statValue(stat.firstValue, isHigher: stat.leadingSide == .first, color: firstColor)
                Spacer()
                if let difference = stat.difference {
                    Text(difference == 0 ? "Equal" : "Difference: \(difference)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                Spacer()
                statValue(stat.secondValue, isHigher: stat.leadingSide == .second, color: secondColor)
            }
            HStack(spacing: 12) {
                statBar(value: stat.firstValue, color: firstColor)
                statBar(value: stat.secondValue, color: secondColor)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(stat.title)
        .accessibilityValue(
            "\(comparison.first.name): \(stat.firstValue.map(String.init) ?? "Not available"); "
                + "\(comparison.second.name): \(stat.secondValue.map(String.init) ?? "Not available")")
    }

    private func statValue(_ value: Int?, isHigher: Bool, color: Color) -> some View {
        HStack(spacing: 4) {
            if isHigher {
                Image(systemName: "plus.circle.fill")
                    .font(.caption)
                    .accessibilityHidden(true)
            }
            Text(value.map(String.init) ?? "—")
                .monospacedDigit()
        }
        .font(.subheadline.weight(isHigher ? .bold : .regular))
        .foregroundStyle(isHigher ? color : .primary)
    }

    private func statBar(value: Int?, color: Color) -> some View {
        ProgressView(value: Double(max(0, value ?? 0)), total: Double(comparison.statMaximum))
            .tint(color)
            .accessibilityHidden(true)
    }

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("About")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            valueRow("Height", first: comparison.first.formattedHeight, second: comparison.second.formattedHeight)
            Divider()
            valueRow("Weight", first: comparison.first.formattedWeight, second: comparison.second.formattedWeight)
            Divider()
            valueRow(
                "Abilities",
                first: comparison.first.abilities.isEmpty ? "Not available" : comparison.first.abilities.joined(separator: "\n"),
                second: comparison.second.abilities.isEmpty ? "Not available" : comparison.second.abilities.joined(separator: "\n"))
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
    }

    private func valueRow(_ title: String, first: String, second: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(alignment: .top, spacing: 12) {
                Text(first).frame(maxWidth: .infinity, alignment: .leading)
                Text(second).frame(maxWidth: .infinity, alignment: .trailing)
            }
            .font(.subheadline)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue("\(comparison.first.name): \(first); \(comparison.second.name): \(second)")
    }
}

private struct PokemonComparisonSummary: View {
    let pokemon: Pokemon
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(spacing: 10) {
            Text(String(format: "#%03d", pokemon.id))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            CachedPokemonImage(url: pokemon.imageURL)
                .frame(height: 100)
            Text(pokemon.name)
                .font(.headline)
                .multilineTextAlignment(.center)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
            ForEach(pokemon.types, id: \.self) { type in
                Text(type.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DesignSystem.Colors.onPokemonType)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(DesignSystem.Colors.pokemonType(type), in: Capsule())
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
        .overlay(alignment: .top) {
            UnevenRoundedRectangle(topLeadingRadius: 16, topTrailingRadius: 16)
                .fill(DesignSystem.Colors.pokemonType(pokemon.types.first ?? .unknown))
                .frame(height: 5)
        }
        .accessibilityElement(children: .combine)
    }
}
