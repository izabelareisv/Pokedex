import SwiftData

@Model
final class FavoritePokemon {
    @Attribute(.unique) var pokemonID: Int

    init(pokemonID: Int) { self.pokemonID = pokemonID }
}
