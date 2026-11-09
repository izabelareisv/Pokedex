import Foundation

struct Pokemon: Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    let imageURL: URL?
    let weight: Double
    let height: Double
    let types: [PokemonType]
    let abilities: [String]
    let moves: [String]
    let stats: [PokemonStat]
    let speciesURL: String

    var formattedWeight: String {
        Measurement(value: weight, unit: UnitMass.kilograms).formatted(
            .measurement(width: .abbreviated, usage: .asProvided).locale(Locale(identifier: "en_US")))
    }
    var formattedHeight: String {
        Measurement(value: height, unit: UnitLength.meters).formatted(
            .measurement(width: .abbreviated, usage: .asProvided).locale(Locale(identifier: "en_US")))
    }

    init(response: PokemonDetailsResponse) {
        id = response.id
        name = response.name.capitalized
        imageURL = response.sprites.other?.officialArtwork?.frontDefault.flatMap(URL.init(string:))
        weight = Double(response.weight) / 10
        height = Double(response.height) / 10
        types = response.types.map { PokemonType(rawValue: $0.type.name) ?? .unknown }
        abilities = response.abilities.map {
            $0.ability.name.replacingOccurrences(of: "-", with: " ").capitalized
        }
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
        case "hp": "HP"
        case "attack": "Attack"
        case "defense": "Defense"
        case "special-attack": "Special Attack"
        case "special-defense": "Special Defense"
        case "speed": "Speed"
        default: name.capitalized
        }
    }
    // Shared visual scale across Pokémon; the displayed value remains unchanged.
    private static let barMaximum = 150.0
    var fraction: Double { min(max(Double(value) / Self.barMaximum, 0), 1) }
}

extension URL {
    var pokemonID: Int? { Int(lastPathComponent) }
}

// Display names follow the API type identifiers.
enum PokemonType: String, CaseIterable, Sendable {
    case normal, fighting, flying, poison, ground, rock, bug, ghost, steel
    case fire, water, grass, electric, psychic, ice, dragon, dark, fairy, stellar, unknown

    var title: String {
        rawValue.capitalized
    }
}
