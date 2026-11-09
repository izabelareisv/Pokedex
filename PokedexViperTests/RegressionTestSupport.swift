import Foundation

#if canImport(PokedexCore)
    @testable import PokedexCore
#else
    @testable import PokedexViper
#endif

enum RegressionFixtures {
    static let nextPage = URL(string: "https://test.local/page2")!

    static func pokemon(_ id: Int, hp: Int? = nil) -> Pokemon {
        Pokemon(response: response(id, hp: hp))
    }

    static func response(_ id: Int, hp: Int? = nil) -> PokemonDetailsResponse {
        PokemonDetailsResponse(
            id: id, name: "pokemon-\(id)", height: 4, weight: 60,
            types: [PokemonTypeResponse(type: PokemonTypeData(name: id == 94 ? "ghost" : "electric", url: ""))],
            abilities: [],
            stats: [Stat(baseStat: hp ?? id, effort: 0, stat: StatDetails(name: "hp", url: ""))],
            moves: [], sprites: Sprites(other: nil), species: Species(name: "species-\(id)", url: "https://test.local/species/\(id)/"))
    }

    static func noDelay(_ duration: Duration) async throws { try Task.checkCancellation() }
}

actor RegressionGate {
    private var entered = false
    private var entryWaiter: CheckedContinuation<Void, Never>?
    private var releaseWaiter: CheckedContinuation<Void, Never>?

    func pause() async {
        entered = true
        entryWaiter?.resume()
        entryWaiter = nil
        await withCheckedContinuation { releaseWaiter = $0 }
    }

    func waitForEntry() async {
        if entered { return }
        await withCheckedContinuation { entryWaiter = $0 }
    }

    func release() {
        releaseWaiter?.resume()
        releaseWaiter = nil
    }
}

actor RegressionDelay {
    let gate: RegressionGate
    private(set) var durations: [Duration] = []

    init(gate: RegressionGate) { self.gate = gate }

    func sleep(_ duration: Duration) async throws {
        durations.append(duration)
        await gate.pause()
        try Task.checkCancellation()
    }
}

actor RegressionInteractor: SearchInteractorProtocol {
    private(set) var listRequests: [URL?] = []
    private(set) var detailIDs: [Int] = []
    private(set) var remoteQueries: [String] = []
    private(set) var active = 0
    private(set) var peak = 0
    private var failedIDs: Set<Int>
    private var remoteFailure: APIError?
    private var pageFailure: APIError?
    let initialFailure: APIError?
    let nextIDs: [Int]
    let detailGate: RegressionGate?
    let remoteGate: RegressionGate?
    let ignoreRemoteCancellation: Bool
    let hpValues: [Int: Int]

    init(
        failedIDs: Set<Int> = [], remoteFailure: APIError? = nil,
        pageFailure: APIError? = nil, initialFailure: APIError? = nil,
        nextIDs: [Int] = [25, 94], detailGate: RegressionGate? = nil,
        remoteGate: RegressionGate? = nil, ignoreRemoteCancellation: Bool = false,
        hpValues: [Int: Int] = [:]
    ) {
        self.failedIDs = failedIDs
        self.remoteFailure = remoteFailure
        self.pageFailure = pageFailure
        self.initialFailure = initialFailure
        self.nextIDs = nextIDs
        self.detailGate = detailGate
        self.remoteGate = remoteGate
        self.ignoreRemoteCancellation = ignoreRemoteCancellation
        self.hpValues = hpValues
    }

    func recover() {
        failedIDs = []
        remoteFailure = nil
        pageFailure = nil
    }

    func getPokemonList(url: URL?) async throws -> PokemonPage {
        listRequests.append(url)
        if url == nil, let initialFailure { throw initialFailure }
        if url != nil, let pageFailure { throw pageFailure }
        let ids = url == nil ? [1] : nextIDs
        return PokemonPage(
            results: ids.map { PokemonResults(name: "pokemon-\($0)", url: "https://test.local/pokemon/\($0)/") },
            next: url == nil ? RegressionFixtures.nextPage : nil, isOffline: false)
    }

    func getPokemonDetails(url: String) async throws -> ServiceValue<Pokemon> {
        let id = URL(string: url)!.pokemonID!
        detailIDs.append(id)
        active += 1
        peak = max(peak, active)
        defer { active -= 1 }
        if id == 25, let detailGate { await detailGate.pause() }
        try await Task.sleep(for: .milliseconds(1))
        if failedIDs.contains(id) { throw APIError.offline }
        return ServiceValue(value: RegressionFixtures.pokemon(id, hp: hpValues[id]))
    }

    func getDescription(for pokemon: Pokemon) async throws -> String? { nil }

    func findPokemon(query: String) async throws -> ServiceValue<Pokemon>? {
        remoteQueries.append(query)
        if let remoteGate { await remoteGate.pause() }
        if !ignoreRemoteCancellation { try Task.checkCancellation() }
        if let remoteFailure { throw remoteFailure }
        switch query {
        case "pokemon-25", "pikachu", "25": return ServiceValue(value: RegressionFixtures.pokemon(25))
        case "pokemon-94", "94": return ServiceValue(value: RegressionFixtures.pokemon(94))
        default: return nil
        }
    }
}

actor RegressionHTTPClient: HTTPClientProtocol {
    let status: Int
    private(set) var urls: [URL] = []

    init(status: Int = 200) { self.status = status }

    func request<T: Decodable & Sendable>(url: URL) async throws -> T {
        urls.append(url)
        if status != 200 { throw APIError.httpStatus(status) }
        let data = try JSONEncoder().encode(RegressionFixtures.response(25))
        return try JSONDecoder().decode(T.self, from: data)
    }
}

extension PokemonViewState {
    var pokemon: [Pokemon]? {
        guard case .loaded(let pokemon) = self else { return nil }
        return pokemon
    }
}
