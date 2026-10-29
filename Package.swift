// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PokedexViper",
    defaultLocalization: "en",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [.library(name: "PokedexCore", targets: ["PokedexCore"])],
    targets: [
        .target(
            name: "PokedexCore", path: "PokedexViper",
            exclude: [
                "Domain/FavoritePokemon.swift", "Assets.xcassets", "Preview Content", "Resources",
                "PokedexViperApp.swift",
                "Screens/PokedexSearch/View", "Screens/PokedexSearch/Router",
                "pikachuRunning.gif", "pokeball-splash.gif", "pokeboll-loading.gif",
            ],
            sources: [
                "Service", "Cache", "Domain",
                "Screens/PokedexSearch/Entity", "Screens/PokedexSearch/Interactor",
                "Screens/PokedexSearch/Presenter",
            ]),
        .testTarget(name: "PokedexViperTests", dependencies: ["PokedexCore"], path: "PokedexViperTests"),
    ]
)
