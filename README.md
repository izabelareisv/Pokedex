# Pokédex · SwiftUI + VIPER

[![iOS CI](https://github.com/izabelareisv/Pokedex/actions/workflows/ci.yml/badge.svg)](https://github.com/izabelareisv/Pokedex/actions/workflows/ci.yml)

An iOS 17.2+ Pokédex powered by [PokéAPI](https://pokeapi.co/), built with Swift 6, SwiftUI, Observation and SwiftData. English and Brazilian Portuguese are supported.

![Pikachu loading animation](PokedexViper/pikachuRunning.gif)

*Bundled loading artwork, not a recording of the application. App screenshots should be captured on an iOS simulator before publishing.*

## Run

Open `PokedexViper.xcodeproj` in Xcode 16.4 or later, select the shared **PokedexViper** scheme and an iPhone simulator, then run. No API key or third party app dependency is required.

From the repository root, run the core tests with `swift test`, or the complete hosted iOS suite with:

```sh
xcodebuild test -project PokedexViper.xcodeproj -scheme PokedexViper \
  -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO
```

With Xcode installed, [Swift Testing is bundled with the toolchain](https://github.com/swiftlang/swift-testing). Command Line Tools installations may require explicit framework/library search paths; the iOS application and SwiftData macros require Xcode.

## Features

- Evolution families in Pokémon details, including branching paths, default evolution conditions, the current Pokémon and navigation to relatives. Species and evolution chains use the same disk-cache TTL and offline fallback as Pokémon details. Family member details resolve through the species' default variety with at most four concurrent member lookups. An evolution error remains inside its section with a retry action.
- Compare two Pokémon from the list, favorites or search results. Tap **Compare**, select two cards, then tap **Compare Pokémon**. Compare base stats on a shared scale, with higher values highlighted, plus types, height, weight and abilities. Selection stays available across search and filter changes; comparison reuses loaded data without additional API requests.
- Pages of 24 Pokémon, starting at Bulbasaur, with at most six concurrent detail requests. Scrolling loads the next page; an explicit load button is also available.
- Search by loaded name or number with a cancellable 300 ms debounce; type and favorites filters. Filters apply to loaded pages, and pagination stays available while filtering.
- Detail artwork, localized type/stat names, properly converted kg/m measurements, and species descriptions loaded only on demand.
- SwiftData favorites persist across launches. Save failures are dismissible and roll back the failed change.
- Cache actor with atomic JSON files in Caches, a 24 hour TTL and expired-data fallback when a network request reports an offline error. A banner identifies offline results. The offline banner also observes system connectivity, including when fresh cache data avoids a network request. Cache eviction by iOS is expected; offline use is limited to previously cached pages and images. Species descriptions and evolution chains can be reused offline after they have been cached.
- Image requests share an actor, deduplicate in-flight downloads and use a bounded memory/disk URLCache. Artwork is reused by URL until cache eviction; data TTL applies to the Pokémon JSON rather than image files.
- Adaptive layouts, semantic colors, VoiceOver labels, standard back navigation and Dynamic Type support.

## Why VIPER with SwiftUI?

The **View** renders one exhaustive state and forwards intent. The **Presenter** owns paging, bounded structured concurrency and filtering on the main actor. The **Interactor** translates DTOs into domain values. The **Service** is the single owner of data caching and uses an injected HTTP client. The **Router** assembles the module, owns the navigation path and builds destinations.

Protocols are used at the network, cache, service and interactor boundaries so tests can replace I/O. DTOs and domain values are `Sendable`; shared mutable caches are actors. The model exposes artwork URLs, localized measurements and typed Pokémon types without exposing the API's nested sprite payload to SwiftUI.

The trade-off is more types than a small MVVM application needs. SwiftUI already provides observation and navigation presentation, so there is no UIKit-style view protocol or presenter-to-view reference. SwiftData queries remain in the UI integration layer. A failed species description does not remove an otherwise valid Pokémon card.

The list tolerates partial failures: successful Pokémon stay visible, one inline notice counts missing items, and retry fetches only those items. Cancelled screen tasks stop their child requests without reporting a user-visible networking error. Pages are sorted by ID and merged without duplicate cards.

## Validation

Evolution tests cover branching paths, default and alternative conditions, form-specific requirements, species-to-variety resolution, metadata cache reuse, expired disk cache offline fallback, server failures, bounded concurrency, cancellation and species without evolutions.

Swift Testing covers HTTP status handling, snake_case and hyphenated-key decoding, malformed data, offline errors, cache reuse through the interactor, file cache expiration/offline fallback, domain measurements, concurrency bounds, loading/success/empty/error/cancellation states, partial retry and pagination/filtering. Tests use URLProtocol and actor mocks, without live API requests. The core suite has 18 tests; an additional hosted iOS test verifies SwiftData favorites across store reopening and deletion. The core also tests cached image reuse after URLSession invalidation and detail-task cancellation.

GitHub Actions runs SwiftLint, core tests and `xcodebuild test`. SwiftLint uses an explicit correctness-focused rule set rather than a large stylistic baseline. The badge reports actual workflow status after the changes are pushed; it is not a claim that CI has already run.

Before release, validate the app in Xcode with both languages, light/dark appearances, VoiceOver, accessibility text sizes, airplane mode and a relaunch after favoriting. This workspace has Command Line Tools but no Xcode or iOS simulator, so visual iOS validation, the hosted SwiftData test and screenshots are pending. The 18 core tests and a temporary macOS adaptation of the SwiftUI expressions passed locally. SwiftLint is configured for CI but is not installed locally; local formatting is checked with swift-format.


See [CHANGELOG.md](CHANGELOG.md) for the implementation history.
