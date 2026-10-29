# Changelog

## Unreleased

- Replace serial list loading with bounded structured concurrency and 24-item pagination from offset zero.
- Introduce typed HTTP errors, status validation, injectable dependencies and privacy-aware logging.
- Centralize caching in the service with an actor, atomic JSON files, TTL and offline fallback.
- Map transport responses into Sendable domain models with typed Pokémon types and corrected measurement units.
- Move startup loading to the view task, add explicit presentation state, cancellation and partial-failure retry.
- Adopt Observation, NavigationStack, router-owned navigation and debounced filters.
- Add SwiftData favorites, image caching, adaptive layouts and accessibility labels.
- Localize the interface in English and Brazilian Portuguese using a string catalog.
- Remove the unused microphone, view protocol, type erasure and obsolete helpers/views.
- Add Swift Testing targets, Swift 6 strict concurrency, SwiftLint configuration and iOS CI.
- Document architecture decisions, cache behavior and remaining simulator validation.
