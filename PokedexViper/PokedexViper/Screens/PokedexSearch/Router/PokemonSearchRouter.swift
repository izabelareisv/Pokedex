//
//  PokemonSearchRouter.swift
//  PokedexViper
//
//  Created by Izabela Reis on 9/12/24.
//

import SwiftUI

@MainActor
final class PokemonSearchRouter {
    /// Assembles and returns the complete PokemonSearch module (View + Presenter + Interactor)
    static func createModule() -> some View {
        // Instantiate the service responsible for API communication
        let service = PokemonService()
        // Instantiate the interactor with the service dependency
        let interactor = PokemonSearchInteractor(pokemonService: service)
        // Instantiate the presenter with the interactor (input)
        let presenter = PokemonSearchPresenter(interactor: interactor)
        // Inject the presenter into the View
        return PokemonSearchView(presenter: presenter)
    }
}
