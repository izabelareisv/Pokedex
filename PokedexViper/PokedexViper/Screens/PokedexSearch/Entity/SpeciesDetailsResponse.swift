//
//  SpeciesDetailsResponse.swift
//  PokedexViper
//
//  Created by Izabela Reis on 9/20/24.
//

import Foundation

struct SpeciesDetailsResponse: Codable {
    let flavorTextEntries: [FlavorTextEntry]

    enum CodingKeys: String, CodingKey {
        case flavorTextEntries = "flavor_text_entries"
    }
}

struct FlavorTextEntry: Codable {
    let flavorText: String
    let language: Language

    enum CodingKeys: String, CodingKey {
        case flavorText = "flavor_text"
        case language
    }
}

struct Language: Codable {
    let name: String
    let url: String
}
