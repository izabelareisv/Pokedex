//
//  PokemonSearchInteractor.swift
//  PokedexViper
//
//  Created by Izabela Reis on 9/12/24.
//

import Foundation

@MainActor
// MARK: - Interactor Protocol
protocol PokemonSearchInteractorProtocol {
    func getPokemonList() async throws -> PokemonListResponse
    func getPokemonDetails(url: String) async throws -> PokemonDetailsResponse
}

@MainActor
class PokemonSearchInteractor: PokemonSearchInteractorProtocol {
    private let pokemonService: PokemonServiceProtocol
    var presenter: (any PokemonSearchPresenterProtocol)?
    private var pokemonDetailsCache: [String: PokemonDetailsResponse] = [:]
    private let cacheManager = PokemonCacheManager.shared

// MARK: - Init
    init(pokemonService: PokemonServiceProtocol) {
        self.pokemonService = pokemonService
    }

    // MARK: - Methods
    func getPokemonList() async throws -> PokemonListResponse {
        if let cachedList = cacheManager.getCachedList() {
            print("✅ Returning cached Pokémon list from Interactor.")
            return cachedList
        }

        let list = try await pokemonService.fetchPokemonList()
        cacheManager.saveListToCache(list)
        return list
    }

    func getPokemonDetails(url: String) async throws -> PokemonDetailsResponse {
        if let cached = pokemonDetailsCache[url] {
            print("✅ Returning cached details for \(url)")
            return cached
        }

        let details = try await pokemonService.fetchPokemonDetails(url: url)
        pokemonDetailsCache[url] = details
        return details
    }
}
