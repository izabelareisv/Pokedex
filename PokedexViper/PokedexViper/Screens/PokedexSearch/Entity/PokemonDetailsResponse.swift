//
//  Pokemon.swift
//  PokedexViper
//
//  Created by Izabela Reis on 9/12/24.
//

import Foundation

// Model for a Pokémon
struct PokemonDetailsResponse: Codable, Identifiable {
    /// Unique identifier for the Pokémon
    let id: Int
    /// Name of the Pokémon
    let name: String
    /// Height of the Pokémon
    let height: Int
    /// Weight of the Pokémon
    let weight: Int
    /// Types of the Pokémon (e.g., Fire, Water)
    let types: [PokemonType]
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
    /// Flavor  of the Pokémon
    var flavorText: String?
}

// MARK: - Species
struct Species: Codable {
    let name: String
    let url: String
}

// MARK: - Types
struct PokemonType: Codable {
    let type: PokemonTypeData
}

struct PokemonTypeData: Codable {
    /// Name of the type (e.g., Fire, Water)
    let name: String
    /// URL of the type
    let url: String
}

// MARK: - Abilities
struct Ability: Codable {
    /// Details of the ability
    let ability: AbilityDetail
}

struct AbilityDetail: Codable {
    /// Name of the ability
    let name: String
    /// URL of the ability
    let url: String
}

// MARK: - Statistics
struct Stat: Codable {
    /// Base stat of the Pokémon
    let baseStat: Int
    /// Effort associated with this stat
    let effort: Int
    /// Details of the stat
    let stat: StatDetails
    
    private enum CodingKeys: String, CodingKey {
        case baseStat = "base_stat"
        case effort = "effort"
        case stat = "stat"
    }
}

struct StatDetails: Codable {
    /// Name of the stat (e.g., HP, Attack)
    let name: String
    /// URL of the stat
    let url: String
}

// MARK: - Moves {
struct Move: Codable {
    /// Content of the move
    let move: MoveContainer
}

struct MoveContainer: Codable {
    /// Name of the move
    let name: String
    /// URL of the move
    let url: String
}

// MARK: - Sprites {
struct Sprites: Codable {
    let other: Other
}

struct Other: Codable {
    let officialArtwork: OfficialArtwork
    
    private enum CodingKeys: String, CodingKey {
        case officialArtwork = "official-artwork"
    }
}

struct OfficialArtwork: Codable {
    let frontDefault: String
    let frontShiny: String
    
    private enum CodingKeys: String, CodingKey {
        case frontDefault = "front_default"
        case frontShiny = "front_shiny"
    }
}
