//
//  PokemonService.swift
//  PokedexViper
//
//  Created by Izabela Reis on 9/12/24.
//

import Foundation

// Service Protocol
protocol PokemonServiceProtocol {
    func fetchPokemonList() async throws -> PokemonListResponse
    func fetchPokemonDetails(url: String) async throws -> PokemonDetailsResponse
}

class PokemonService: PokemonServiceProtocol {
    private let pokemonCacheManager = PokemonCacheManager.shared

    func fetchPokemonList() async throws -> PokemonListResponse {
        if let cachedList = pokemonCacheManager.getCachedList() {
            print("Returning cached Pokémon list.")
            return cachedList
        }

        guard let url = URL(string: "https://pokeapi.co/api/v2/pokemon?offset=5&limit=102") else {
            throw URLError(.badURL)
        }

        let pokemonList: PokemonListResponse = try await APIClient.shared.request(url: url)
        pokemonCacheManager.saveListToCache(pokemonList)
        return pokemonList
    }

    func fetchPokemonDetails(url: String) async throws -> PokemonDetailsResponse {
        let pokemonID = extractPokemonIDFromURL(from: url)
        guard let url = URL(string: url) else { throw URLError(.badURL) }

        var pokemonDetails: PokemonDetailsResponse = try await APIClient.shared.request(url: url)

        if let id = pokemonID {
            let essentialData = PokemonEssentialData(id: id,
                                                     name: pokemonDetails.name,
                                                     imageURL: pokemonDetails.sprites.other.officialArtwork.frontDefault)
            pokemonCacheManager.saveDetailToCache(essentialData)
        }

        let speciesDetails = try await fetchSpeciesDetails(from: pokemonDetails.species.url)
        pokemonDetails.flavorText = speciesDetails.flavorTextEntries.first?.flavorText
        return pokemonDetails
    }

    func fetchSpeciesDetails(from url: String) async throws -> SpeciesDetailsResponse {
        guard let url = URL(string: url) else { throw URLError(.badURL) }
        return try await APIClient.shared.request(url: url)
    }

    private func extractPokemonIDFromURL(from url: String) -> Int? {
        let components = url.components(separatedBy: "/")
        return Int(components.last ?? "")
    }
}
