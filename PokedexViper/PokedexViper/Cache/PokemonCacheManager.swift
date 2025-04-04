//
//  PokemonCacheManager.swift
//  PokedexViper
//
//  Created by Izabela Reis  on 02/04/25.
//

import Foundation

class PokemonCacheManager {
    static let shared = PokemonCacheManager()

    private var cachedPokemonList: PokemonListResponse?
    private var cachedPokemonDetails: [Int: PokemonEssentialData] = [:]

    // MARK: - List Cache
    func getCachedList() -> PokemonListResponse? {
        return cachedPokemonList ?? loadListFromDefaults()
    }

    func saveListToCache(_ list: PokemonListResponse) {
        cachedPokemonList = list
        if let data = try? JSONEncoder().encode(list) {
            UserDefaults.standard.set(data, forKey: "pokemonList")
        }
    }

    private func loadListFromDefaults() -> PokemonListResponse? {
        if let data = UserDefaults.standard.data(forKey: "pokemonList"),
           let list = try? JSONDecoder().decode(PokemonListResponse.self, from: data) {
            cachedPokemonList = list
            return list
        }
        return nil
    }

    // MARK: - Details Cache
    func getCachedDetail(for id: Int) -> PokemonEssentialData? {
        return cachedPokemonDetails[id] ?? loadDetailsFromDefaults().first(where: { $0.id == id })
    }

    func saveDetailToCache(_ detail: PokemonEssentialData) {
        cachedPokemonDetails[detail.id] = detail

        var detailsList = loadDetailsFromDefaults()
        if !detailsList.contains(where: { $0.id == detail.id }) {
            detailsList.append(detail)
            if let data = try? JSONEncoder().encode(detailsList) {
                UserDefaults.standard.set(data, forKey: "pokemonDetails")
            }
        }
    }

    private func loadDetailsFromDefaults() -> [PokemonEssentialData] {
        if let data = UserDefaults.standard.data(forKey: "pokemonDetails"),
           let details = try? JSONDecoder().decode([PokemonEssentialData].self, from: data) {
            return details
        }
        return []
    }
}
