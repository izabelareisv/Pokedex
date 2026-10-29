import Foundation

struct Pokemon: Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    let imageURL: URL?
    let weight: Double
    let height: Double
    let types: [PokemonType]
    let moves: [String]
    let stats: [PokemonStat]
    let speciesURL: String

    var formattedWeight: String {
        Measurement(value: weight, unit: UnitMass.kilograms).formatted(
            .measurement(width: .abbreviated, usage: .asProvided))
    }
    var formattedHeight: String {
        Measurement(value: height, unit: UnitLength.meters).formatted(
            .measurement(width: .abbreviated, usage: .asProvided))
    }

    init(response: PokemonDetailsResponse) {
        id = response.id
        name = response.name.capitalized
        imageURL = response.sprites.other?.officialArtwork?.frontDefault.flatMap(URL.init(string:))
        weight = Double(response.weight) / 10
        height = Double(response.height) / 10
        types = response.types.map { PokemonType(rawValue: $0.type.name) ?? .unknown }
        moves = response.moves.prefix(2).map {
            $0.move.name.replacingOccurrences(of: "-", with: " ").capitalized
        }
        stats = response.stats.map { PokemonStat(name: $0.stat.name, value: $0.baseStat) }
        speciesURL = response.species.url
    }
}

struct PokemonStat: Hashable, Sendable {
    let name: String
    let value: Int
    var title: String {
        switch name {
        case "hp": String(localized: "HP")
        case "attack": String(localized: "Attack")
        case "defense": String(localized: "Defense")
        case "special-attack": String(localized: "Special Attack")
        case "special-defense": String(localized: "Special Defense")
        case "speed": String(localized: "Speed")
        default: name.capitalized
        }
    }
    var fraction: Double { min(max(Double(value) / 255, 0), 1) }
}

extension URL {
    var pokemonID: Int? { Int(lastPathComponent) }
}

// Stable API identifiers; display names are localized independently.
enum PokemonType: String, CaseIterable, Sendable {
    case normal, fighting, flying, poison, ground, rock, bug, ghost, steel
    case fire, water, grass, electric, psychic, ice, dragon, dark, fairy, stellar, unknown

    var title: String {
        switch self {
        case .unknown: String(localized: "Unknown")
        case .stellar: String(localized: "Stellar")
        case .normal: String(localized: "Normal")
        case .fighting: String(localized: "Fighting")
        case .flying: String(localized: "Flying")
        case .poison: String(localized: "Poison")
        case .ground: String(localized: "Ground")
        case .rock: String(localized: "Rock")
        case .bug: String(localized: "Bug")
        case .ghost: String(localized: "Ghost")
        case .steel: String(localized: "Steel")
        case .fire: String(localized: "Fire")
        case .water: String(localized: "Water")
        case .grass: String(localized: "Grass")
        case .electric: String(localized: "Electric")
        case .psychic: String(localized: "Psychic")
        case .ice: String(localized: "Ice")
        case .dragon: String(localized: "Dragon")
        case .dark: String(localized: "Dark")
        case .fairy: String(localized: "Fairy")
        }
    }
}
