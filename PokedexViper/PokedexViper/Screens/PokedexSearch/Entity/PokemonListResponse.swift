//
//  PokemonList.swift
//  PokedexViper
//
//  Created by Izabela Reis on 9/15/24.
//

import Foundation

// Model for the Pokémon list response
struct PokemonListResponse: Codable {
    /// Total number of Pokémon available (can be used for pagination)
    let count: Int
    /// URL to fetch the next set of Pokémon results, if available
    let next: String?
    /// URL to fetch the previous set of Pokémon results, if available
    let previous: String?
    /// List of Pokémon returned by the API in the current response
    let results: [PokemonResults]
}

// Model for a Pokémon
struct PokemonResults: Codable {
    let name: String
    let url: String
    
    init(name: String, url: String) {
        self.name = name
        self.url = url
    }
}

struct PokemonEssentialData: Codable, Identifiable {
    let id: Int
    let name: String
    let imageURL: String
}

