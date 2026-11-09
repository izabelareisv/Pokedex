//
//  SpeciesDetailsResponse.swift
//  PokedexViper
//
//  Created by Izabela Reis on 9/20/24.
//

import Foundation

struct SpeciesDetailsResponse: Codable, Sendable {
    let flavorTextEntries: [FlavorTextEntry]
    let evolutionChain: EvolutionChainResource?
    let varieties: [PokemonSpeciesVariety]?

}

struct FlavorTextEntry: Codable, Sendable {
    let flavorText: String
    let language: Language

}

struct Language: Codable, Sendable {
    let name: String
    let url: String
}

struct EvolutionChainResource: Codable, Sendable {
    let url: String
}

struct PokemonSpeciesVariety: Codable, Sendable {
    let isDefault: Bool
    let pokemon: EvolutionResource
}
