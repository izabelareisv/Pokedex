import Foundation

struct PokemonEvolutionFamily: Sendable {
    struct Reference: Identifiable, Sendable {
        let species: EvolutionResource
        let parentName: String?
        let depth: Int
        let conditions: [String]
        var id: String { species.url }
    }

    struct Member: Identifiable, Sendable {
        let reference: Reference
        let pokemon: Pokemon
        var id: String { reference.id }
    }

    let members: [Member]

    static func references(from response: EvolutionChainResponse) -> [Reference] {
        func visit(_ link: EvolutionChainLink, parent: String?, depth: Int) -> [Reference] {
            let defaults = link.evolutionDetails.filter { $0.isDefault != false }
            let details = defaults.isEmpty ? link.evolutionDetails : defaults
            var conditions: [String] = []
            for detail in details {
                let label = detail.displayCondition
                if !conditions.contains(label) { conditions.append(label) }
            }
            if parent != nil && conditions.isEmpty { conditions = ["Special conditions"] }
            let reference = Reference(species: link.species, parentName: parent, depth: depth, conditions: conditions)
            return [reference] + link.evolvesTo.flatMap { visit($0, parent: link.species.title, depth: depth + 1) }
        }
        return visit(response.chain, parent: nil, depth: 0)
    }
}

extension EvolutionDetails {
    var displayCondition: String {
        var parts: [String] = []
        switch trigger?.name {
        case "level-up": parts.append(minLevel.map { "Level \($0)" } ?? "Level up")
        case "trade": parts.append("Trade")
        case "use-item": if item == nil { parts.append("Use an item") }
        case .some(let name): parts.append(name.replacingOccurrences(of: "-", with: " ").capitalized)
        case nil: break
        }
        if let minLevel, trigger?.name != "level-up" { parts.append("Level \(minLevel)") }
        if let item { parts.append("Use \(item.title)") }
        if let heldItem { parts.append("Holding \(heldItem.title)") }
        if let minHappiness { parts.append("Friendship ≥ \(minHappiness)") }
        if let minBeauty { parts.append("Beauty ≥ \(minBeauty)") }
        if let minAffection { parts.append("Affection ≥ \(minAffection)") }
        if let timeOfDay, !timeOfDay.isEmpty {
            parts.append(timeOfDay.replacingOccurrences(of: "-", with: " ").capitalized)
        }
        if gender == 1 { parts.append("Female") }
        if gender == 2 { parts.append("Male") }
        if let knownMove { parts.append("Knows \(knownMove.title)") }
        if let knownMoveType { parts.append("Knows a \(knownMoveType.title) move") }
        if let location { parts.append("At \(location.title)") }
        if let partySpecies { parts.append("\(partySpecies.title) in party") }
        if let partyType { parts.append("\(partyType.title) type in party") }
        if let tradeSpecies { parts.append("For \(tradeSpecies.title)") }
        switch relativePhysicalStats {
        case 1: parts.append("Attack > Defense")
        case 0: parts.append("Attack = Defense")
        case -1: parts.append("Attack < Defense")
        default: break
        }
        if needsOverworldRain == true { parts.append("Overworld rain") }
        if turnUpsideDown == true { parts.append("Hold the device upside down") }
        if nearSpecialRock == true { parts.append("Near a special rock") }
        if needsMultiplayer == true { parts.append("Multiplayer required") }
        if let region { parts.append("In \(region.title)") }
        if let requiredPokemonForm { parts.append("From \(requiredPokemonForm.title)") }
        if let evolvedPokemonForm { parts.append("Into \(evolvedPokemonForm.title)") }
        if let usedMove { parts.append("Use \(usedMove.title)") }
        if let minMoveCount { parts.append("\(minMoveCount)+ move uses") }
        if let minSteps { parts.append("\(minSteps)+ steps") }
        if let minDamageTaken { parts.append("\(minDamageTaken)+ damage taken") }
        if let allowedNatures, !allowedNatures.isEmpty {
            parts.append("Nature: " + allowedNatures.map(\.title).joined(separator: ", "))
        }
        if let conditionExpression {
            if let chance = conditionExpression.percentageChance {
                parts.append("\(chance.formatted(.number.locale(Locale(identifier: "en_US"))))% chance")
            }
            parts.append("Additional conditions apply")
        }
        if isDefault == false, let versionGroup { parts.append("In \(versionGroup.title)") }
        return parts.isEmpty ? "Special conditions" : parts.joined(separator: " · ")
    }
}
