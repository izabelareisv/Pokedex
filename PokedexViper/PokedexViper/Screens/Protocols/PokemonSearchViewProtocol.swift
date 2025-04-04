//
//  PokemonSearchViewProtocol.swift
//  PokedexViper
//
//  Created by Izabela Reis  on 03/04/25.
//

protocol PokemonSearchViewProtocol: AnyObject {
    func showError(_ message: String)
    func showLoading(_ isLoading: Bool)
    func reloadData()
}
