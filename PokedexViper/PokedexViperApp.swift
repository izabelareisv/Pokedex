import SwiftData
import SwiftUI

@main
struct PokedexApp: App {
    @State private var container: ModelContainer?
    @State private var storageFailed = false
    @State private var showingSplash = true

    var body: some Scene {
        WindowGroup {
            Group {
                if storageFailed {
                    ScrollView {
                        PokemonEmptyStateView(
                            title: "Could not open favorites",
                            message: "Please try again.",
                            onAction: openStorage)
                    }
                } else if showingSplash || container == nil {
                    SplashView()
                } else if let container {
                    SearchRouter.createModule().modelContainer(container)
                }
            }
            .environment(\.locale, Locale(identifier: "en_US"))
            .task {
                if container == nil && !storageFailed { openStorage() }
                guard showingSplash else { return }
                do {
                    try await Task.sleep(for: .seconds(1))
                    showingSplash = false
                } catch {}
            }
        }
    }

    private func openStorage() {
        do {
            container = try ModelContainer(for: FavoritePokemon.self)
            storageFailed = false
        } catch { storageFailed = true }
    }
}
