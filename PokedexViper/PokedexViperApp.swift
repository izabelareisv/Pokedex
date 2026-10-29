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
                    ContentUnavailableView {
                        Label("Could not open favorites", systemImage: "externaldrive.badge.exclamationmark")
                    } description: {
                        Text("Please try again.")
                    } actions: {
                        Button("Try again") { openStorage() }
                    }
                } else if showingSplash || container == nil {
                    SplashView()
                } else if let container {
                    SearchRouter.createModule().modelContainer(container)
                }
            }
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
