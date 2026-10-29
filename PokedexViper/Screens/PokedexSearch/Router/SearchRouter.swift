import Observation
import SwiftUI

@MainActor
@Observable
final class SearchRouter {
    var path: [Pokemon] = []

    func showDetails(_ pokemon: Pokemon) { path.append(pokemon) }

    func destination(for pokemon: Pokemon, presenter: SearchPresenter) -> some View {
        PokemonDetailView(pokemon: pokemon, presenter: presenter)
    }

    static func createModule() -> some View {
        let interactor = SearchInteractor(pokemonService: PokemonService())
        return PokedexView(presenter: SearchPresenter(interactor: interactor))
    }
}
