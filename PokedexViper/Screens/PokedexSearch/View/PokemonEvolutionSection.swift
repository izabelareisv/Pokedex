import SwiftUI

struct PokemonEvolutionSection: View {
    enum State {
        case idle
        case loading
        case loaded(ServiceValue<PokemonEvolutionFamily>?)
        case failed(APIError)
    }

    let state: State
    let currentPokemon: Pokemon
    let color: Color
    let onSelect: (Pokemon) -> Void
    let onRetry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Evolution Chain")
                .font(.headline)
                .foregroundStyle(color)
                .frame(maxWidth: .infinity)
                .accessibilityAddTraits(.isHeader)

            switch state {
            case .idle, .loading:
                ProgressView("Loading evolutions…")
                    .frame(maxWidth: .infinity)
            case .failed(let error):
                PokemonEmptyStateView(
                    title: "Could not load evolutions",
                    message: error.localizedDescription,
                    imageSize: 88,
                    actionTitle: "Retry evolutions",
                    onAction: onRetry)
            case .loaded(let result):
                if let result {
                    familyContent(result)
                } else {
                    Text("Evolution information is not available.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func familyContent(_ result: ServiceValue<PokemonEvolutionFamily>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if result.isOffline {
                Label("Offline · showing saved evolutions", systemImage: "wifi.slash")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ForEach(result.value.members) { member in
                VStack(alignment: .leading, spacing: 8) {
                    if let parentName = member.reference.parentName {
                        Label("From \(parentName)", systemImage: "arrow.turn.down.right")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                        ForEach(Array(member.reference.conditions.enumerated()), id: \.offset) { index, condition in
                            if index > 0 {
                                Text("or").font(.caption).foregroundStyle(.secondary)
                            }
                            Text(condition)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if member.pokemon.id == currentPokemon.id {
                        memberCard(member, isCurrent: true)
                            .accessibilityAddTraits(.isSelected)
                    } else {
                        Button { onSelect(member.pokemon) } label: {
                            memberCard(member, isCurrent: false)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Opens Pokémon details")
                    }
                }
                .padding(.leading, CGFloat(min(member.reference.depth, 2)) * 8)
            }
            Text(result.value.members.count == 1
                ? "This Pokémon has no evolutions."
                : "Default evolution methods. Conditions can vary by game and form.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func memberCard(_ member: PokemonEvolutionFamily.Member, isCurrent: Bool) -> some View {
        HStack(spacing: 12) {
            CachedPokemonImage(url: member.pokemon.imageURL)
                .frame(width: 56, height: 64)
            VStack(alignment: .leading, spacing: 4) {
                Text(member.pokemon.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(String(format: "#%03d", member.pokemon.id))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                if isCurrent {
                    Text("Current Pokémon")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(color)
                }
            }
            Spacer(minLength: 0)
            if !isCurrent {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(isCurrent ? 0.08 : 0.03), in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isCurrent ? color : .clear, lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }
}
