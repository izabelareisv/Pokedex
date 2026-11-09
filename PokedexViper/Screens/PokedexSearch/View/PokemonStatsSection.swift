import SwiftUI

struct PokemonStatsSection: View {
    let stats: [PokemonStat]
    let color: Color

    private var trackColor: Color { color.opacity(0.16) }

    var body: some View {
        VStack(spacing: 10) {
            Text("Base Stats")
                .font(.headline)
                .foregroundStyle(color)

            VStack(spacing: 8) {
                ForEach(stats, id: \.name) { stat in
                    statRow(stat)
                }
            }
        }
    }

    private func statRow(_ stat: PokemonStat) -> some View {
        HStack(spacing: 9) {
            Text(stat.title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(width: 88, alignment: .leading)

            Text(String(format: "%03d", stat.value))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 28, alignment: .trailing)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(trackColor)
                    Capsule().fill(color)
                        .frame(width: max(3, geometry.size.width * stat.fraction))
                }
            }
            .frame(height: 5)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(stat.title): \(stat.value)"))
    }
}
