//
//  TagColor.swift
//  PokedexViper
//
//  Created by Izabela Reis on 9/20/24.
//

import SwiftUI

enum TagColor {
    case normal
    case fighting
    case flying
    case ground
    case poison
    case rock
    case bug
    case ghost
    case steel
    case fire
    case water
    case grass
    case electric
    case psychic
    case ice
    case dragon
    case dark
    case fairy
    case defaultColor
    
    // Retorna a cor associada ao nome da tag
    var color: Color {
        switch self {
        case .normal:
            return .gray
        case .fighting:
            return .red
        case .flying:
            return .purple.opacity(0.5)
        case .ground:
            return .yellow.opacity(0.5)
        case .poison:
            return .purple.opacity(0.5)
        case .rock:
            return .brown.opacity(0.5)
        case .bug:
            return .green.opacity(0.5)
        case .ghost:
            return .indigo // purple
        case .steel:
            return .gray
        case .fire:
            return .orange
        case .water:
            return .blue
        case .grass:
            return .green
        case .electric:
            return .yellow
        case .psychic:
            return .pink
        case .ice:
            return .cyan
        case .dragon:
            return .blue
        case .dark:
            return .black
        case .fairy:
            return .pink.opacity(0.5)
        case .defaultColor:
            return .gray
        }
    }
    
    // Inicializador para mapear o name para o enum
    init(name: String) {
        switch name.lowercased() {
        case "normal":
            self = .normal
        case "fighting":
            self = .fighting
        case "flying":
            self = .flying
        case "ground":
            self = .ground
        case "poison":
            self = .poison
        case "rock":
            self = .rock
        case "bug":
            self = .bug
        case "ghost":
            self = .ghost
        case "steel":
            self = .steel
        case "fire":
            self = .fire
        case "water":
            self = .water
        case "grass":
            self = .grass
        case "electric":
            self = .electric
        case "psychic":
            self = .psychic
        case "ice":
            self = .ice
        case "dragon":
            self = .dragon
        case "dark":
            self = .dark
        case "fairy":
            self = .fairy
        default:
            self = .defaultColor
        }
    }
}
