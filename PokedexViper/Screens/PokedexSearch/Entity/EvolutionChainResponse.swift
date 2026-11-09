import Foundation

struct EvolutionChainResponse: Codable, Sendable {
    let chain: EvolutionChainLink
}

struct EvolutionResource: Codable, Sendable {
    let name: String
    let url: String

    var title: String { name.replacingOccurrences(of: "-", with: " ").capitalized }
}

struct EvolutionChainLink: Codable, Sendable {
    let species: EvolutionResource
    let evolutionDetails: [EvolutionDetails]
    let evolvesTo: [EvolutionChainLink]
}

struct EvolutionDetails: Codable, Sendable {
    let trigger: EvolutionResource?
    let item: EvolutionResource?
    let heldItem: EvolutionResource?
    let minLevel: Int?
    let minHappiness: Int?
    let minBeauty: Int?
    let minAffection: Int?
    let timeOfDay: String?
    let gender: Int?
    let knownMove: EvolutionResource?
    let knownMoveType: EvolutionResource?
    let location: EvolutionResource?
    let partySpecies: EvolutionResource?
    let partyType: EvolutionResource?
    let tradeSpecies: EvolutionResource?
    let relativePhysicalStats: Int?
    let needsOverworldRain: Bool?
    let turnUpsideDown: Bool?
    let nearSpecialRock: Bool?
    let needsMultiplayer: Bool?
    let region: EvolutionResource?
    let requiredPokemonForm: EvolutionResource?
    let evolvedPokemonForm: EvolutionResource?
    let usedMove: EvolutionResource?
    let minMoveCount: Int?
    let minSteps: Int?
    let minDamageTaken: Int?
    let allowedNatures: [EvolutionResource]?
    let conditionExpression: EvolutionConditionExpression?
    let isDefault: Bool?
    let versionGroup: EvolutionResource?
}

struct EvolutionConditionExpression: Codable, Sendable {
    let percentageChance: Double?
}
