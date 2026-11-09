struct PokemonFavoriteStatus: Equatable, Sendable {
    let pokemonID: Int
    let favoriteIDs: Set<Int>

    var isFavorite: Bool {
        favoriteIDs.contains(pokemonID)
    }
}
