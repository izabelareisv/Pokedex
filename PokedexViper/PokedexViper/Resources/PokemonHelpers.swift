//
//  PokemonHelpers.swift
//  PokedexViper
//
//  Created by Izabela Reis on 9/15/24.
//

import Foundation
import SwiftUI

class PokemonHelpers {
    private static let baseImageURL = "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/"
    
    /// Gera a URL para a imagem do Pokémon com base no ID
    static func getImageURL(for pokemonID: String) -> URL? {
        let urlString = "\(baseImageURL)\(pokemonID).png"
        return URL(string: urlString)
    }
    
    // Função para extrair o ID do Pokémon da URL
    static func extractPokemonID(from urlString: String) -> String? {
        guard let lastComponent = urlString.split(separator: "/").last else {
            return nil
        }
        return String(lastComponent)
    }
    
    // MARK: - Color Helpers
    static func color(from hex: String) -> Color {
        let hex = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let r, g, b, a: Double
        
        if hex.hasPrefix("#") {
            let start = hex.index(hex.startIndex, offsetBy: 1)
            let hexColor = String(hex[start...])
            
            if hexColor.count == 6 {
                let scanner = Scanner(string: hexColor)
                var hexNumber: UInt64 = 0
                
                if scanner.scanHexInt64(&hexNumber) {
                    r = Double((hexNumber & 0xFF0000) >> 16) / 255.0
                    g = Double((hexNumber & 0x00FF00) >> 8) / 255.0
                    b = Double(hexNumber & 0x0000FF) / 255.0
                    a = 1.0
                } else {
                    r = 1.0; g = 1.0; b = 1.0; a = 1.0
                }
            } else {
                r = 1.0; g = 1.0; b = 1.0; a = 1.0
            }
        } else {
            r = 1.0; g = 1.0; b = 1.0; a = 1.0
        }
        
        return Color(red: r, green: g, blue: b, opacity: a)
    }
}
