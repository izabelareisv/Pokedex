//
//  SpeciesDetailsResponse.swift
//  PokedexViper
//
//  Created by Izabela Reis on 9/20/24.
//

import Foundation

struct SpeciesDetailsResponse: Codable, Sendable {
    let flavorTextEntries: [FlavorTextEntry]

}

struct FlavorTextEntry: Codable, Sendable {
    let flavorText: String
    let language: Language

}

struct Language: Codable, Sendable {
    let name: String
    let url: String
}
