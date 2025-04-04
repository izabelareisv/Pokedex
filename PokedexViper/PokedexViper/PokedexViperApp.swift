//
//  PokedexViperApp.swift
//  PokedexViper
//
//  Created by Izabela Reis on 9/12/24.
//

import SwiftUI

@main
struct PokedexApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            if appState.isSplashActive {
                SplashView()
                    .transition(.opacity)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation {
                                appState.isSplashActive = false
                            }
                        }
                    }
            } else {
                PokemonSearchRouter.createModule()
                    .transition(.opacity)
            }
        }
    }
}

// Gerencia o estado do aplicativo, incluindo a tela de splash
final class AppState: ObservableObject {
    @Published var isSplashActive: Bool = true
}
