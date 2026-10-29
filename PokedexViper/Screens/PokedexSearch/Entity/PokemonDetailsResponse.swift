//
//  Pokemon.swift
//  PokedexViper
//
//  Created by Izabela Reis on 9/12/24.
//

import Foundation

// Model for a Pokémon
struct PokemonDetailsResponse: Codable, Sendable, Identifiable {
    /// Unique identifier for the Pokémon
    let id: Int
    /// Name of the Pokémon
    let name: String
    /// Height of the Pokémon
    let height: Int
    /// Weight of the Pokémon
    let weight: Int
    /// Types of the Pokémon (e.g., Fire, Water)
    let types: [PokemonTypeResponse]
    /// Abilities of the Pokémon
    let abilities: [Ability]
    /// Statistics of the Pokémon
    let stats: [Stat]
    /// Moves of the Pokémon
    let moves: [Move]
    /// Sprites of the Pokémon
    let sprites: Sprites
    /// Sprites of the Pokémon
    let species: Species
}

// MARK: - Species
struct Species: Codable, Sendable {
    let name: String
    let url: String
}

// MARK: - Types
struct PokemonTypeResponse: Codable, Sendable {
    let type: PokemonTypeData
}

struct PokemonTypeData: Codable, Sendable {
    /// Name of the type (e.g., Fire, Water)
    let name: String
    /// URL of the type
    let url: String
}

// MARK: - Abilities
struct Ability: Codable, Sendable {
    /// Details of the ability
    let ability: AbilityDetail
}

struct AbilityDetail: Codable, Sendable {
    /// Name of the ability
    let name: String
    /// URL of the ability
    let url: String
}

// MARK: - Statistics
struct Stat: Codable, Sendable {
    /// Base stat of the Pokémon
    let baseStat: Int
    /// Effort associated with this stat
    let effort: Int
    /// Details of the stat
    let stat: StatDetails

}

struct StatDetails: Codable, Sendable {
    /// Name of the stat (e.g., HP, Attack)
    let name: String
    /// URL of the stat
    let url: String
}

// MARK: - Moves {
struct Move: Codable, Sendable {
    /// Content of the move
    let move: MoveContainer
}

struct MoveContainer: Codable, Sendable {
    /// Name of the move
    let name: String
    /// URL of the move
    let url: String
}

// MARK: - Sprites {
struct Sprites: Codable, Sendable {
    let other: Other?
}

struct Other: Codable, Sendable {
    let officialArtwork: OfficialArtwork?

    private enum CodingKeys: String, CodingKey {
        case officialArtwork = "official-artwork"
    }
}

struct OfficialArtwork: Codable, Sendable {
    let frontDefault: String?
    let frontShiny: String?

}
