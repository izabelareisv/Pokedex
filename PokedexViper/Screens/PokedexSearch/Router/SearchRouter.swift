import Observation
import SwiftUI

@MainActor
@Observable
final class SearchRouter {
    enum Route: Hashable {
        case details(Pokemon)
        case comparison(PokemonComparison)
    }

    var path: [Route] = []

    func showDetails(_ pokemon: Pokemon) { path.append(.details(pokemon)) }
    func showComparison(_ comparison: PokemonComparison) { path.append(.comparison(comparison)) }

    @ViewBuilder
    func destination(for route: Route, presenter: SearchPresenter) -> some View {
        switch route {
        case .details(let pokemon):
            PokemonDetailView(pokemon: pokemon, presenter: presenter, onShowPokemon: showDetails)
        case .comparison(let comparison):
            PokemonComparisonView(comparison: comparison)
        }
    }

    static func createModule() -> some View {
        let interactor = SearchInteractor(pokemonService: PokemonService())
        return PokedexView(presenter: SearchPresenter(interactor: interactor))
    }
}
