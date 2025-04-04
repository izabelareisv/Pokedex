//
//  MockPokemonPresenter.swift
//  PokedexViper
//
//  Created by Izabela Reis on 9/12/24.
//

import Foundation
import SwiftUI
import Combine

// Provide mock data for previews
class MockPokemonService: PokemonServiceProtocol {
    func fetchPokemonList() async throws -> PokemonListResponse {
        PokemonListResponse(count: 0, next: "", previous: "", results: [])
    }
    
    func fetchEssentialPokemonList() -> [PokemonEssentialData] {
        let PokemonEssentialData = [PokemonEssentialData(id: 1, name: "Mock Pokemon", imageURL: "")]
        return PokemonEssentialData
    }

    func fetchPokemonDetails(url: String) -> PokemonDetailsResponse {
        let mockPokemonDetails = PokemonDetailsResponse(id: 1,
                                                        name: "Pikachu",
                                                        height: 4,
                                                        weight: 6,
                                                        types: [PokemonType(type: PokemonTypeData(name: "normal", url: ""))],
                                                        abilities: [Ability(ability: AbilityDetail(name: "static", url: ""))],
                                                        stats: [Stat(baseStat: 35, effort: 0, stat: StatDetails(name: "hp",  url: ""))],
                                                        moves: [Move(move: MoveContainer(name: "", url: ""))],
                                                        sprites: Sprites(other: Other(officialArtwork: OfficialArtwork(frontDefault: "", frontShiny: ""))),
                                                        species: Species(name: "", url: ""))
        return mockPokemonDetails
    }

    func fetchSpeciesDetails(url: String) async throws -> SpeciesDetailsResponse {
        return SpeciesDetailsResponse(flavorTextEntries: [FlavorTextEntry(flavorText: "Mock Flavor Text",
                                                                          language: Language(name: "en",
                                                                                             url: ""))])
    }
}
