import Foundation

struct PokemonComparison: Hashable, Sendable {
    let first: Pokemon
    let second: Pokemon

    init?(first: Pokemon, second: Pokemon) {
        guard first.id != second.id else { return nil }
        self.first = first
        self.second = second
    }

    var stats: [ComparedPokemonStat] {
        let standardOrder = ["hp", "attack", "defense", "special-attack", "special-defense", "speed"]
        let names = Set(first.stats.map(\.name) + second.stats.map(\.name))
        let orderedNames = standardOrder.filter { names.contains($0) }
            + names.subtracting(standardOrder).sorted()
        return orderedNames.map { name in
            ComparedPokemonStat(
                name: name,
                firstValue: first.stats.first { $0.name == name }?.value,
                secondValue: second.stats.first { $0.name == name }?.value)
        }
    }

    /// Both Pokémon use the same scale, including unusually high base stats.
    var statMaximum: Int {
        max(150, (first.stats + second.stats).map(\.value).max() ?? 0)
    }
}

struct ComparedPokemonStat: Identifiable, Equatable, Sendable {
    enum Side: Equatable, Sendable { case first, second }

    let name: String
    let firstValue: Int?
    let secondValue: Int?

    var id: String { name }
    var title: String { PokemonStat(name: name, value: 0).title }
    var leadingSide: Side? {
        guard let firstValue, let secondValue, firstValue != secondValue else { return nil }
        return firstValue > secondValue ? .first : .second
    }
    var difference: Int? {
        guard let firstValue, let secondValue else { return nil }
        return abs(firstValue - secondValue)
    }
}

struct PokemonComparisonSelection {
    private(set) var pokemon: [Pokemon] = []

    var isFull: Bool { pokemon.count == 2 }
    var comparison: PokemonComparison? {
        guard isFull else { return nil }
        return PokemonComparison(first: pokemon[0], second: pokemon[1])
    }

    func contains(_ candidate: Pokemon) -> Bool {
        pokemon.contains { $0.id == candidate.id }
    }

    mutating func toggle(_ candidate: Pokemon) {
        if contains(candidate) {
            remove(id: candidate.id)
        } else if !isFull {
            pokemon.append(candidate)
        }
    }

    mutating func remove(id: Int) {
        pokemon.removeAll { $0.id == id }
    }

    mutating func clear() { pokemon.removeAll() }
}
