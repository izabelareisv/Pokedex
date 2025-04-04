import Combine
import Foundation

@MainActor
protocol PokemonSearchPresenterProtocol: ObservableObject {
    var pokemonList: PokemonListResponse? { get }
    var pokemonDetails: [PokemonDetailsResponse] { get }
    var errorMessage: String? { get }
    var isLoading: Bool { get }
    func fetchPokemonList() async
    func fetchPokemonDetails(url: String) async -> PokemonDetailsResponse?
}

@MainActor
class PokemonSearchPresenter: PokemonSearchPresenterProtocol {

    private let interactor: PokemonSearchInteractorProtocol
    private var cancellables = Set<AnyCancellable>()
    @Published var pokemonList: PokemonListResponse?
    @Published var pokemonDetails: [PokemonDetailsResponse]
    @Published var errorMessage: String?
    @Published var isLoading: Bool = false
    
    init(interactor: PokemonSearchInteractorProtocol) {
        self.interactor = interactor
        self.pokemonList = nil
        self.pokemonDetails = []
        
        Task { await fetchPokemonList() }
    }
    
    /// Load the list of Pokémon
    func fetchPokemonList() async {
        isLoading = true
        errorMessage = nil
        pokemonDetails = []

        do {
            let list = try await interactor.getPokemonList()
            self.pokemonList = list

            guard !list.results.isEmpty else {
                self.errorMessage = "No Pokémon data found."
                return
            }

            let detailURLs = list.results.map { $0.url }
            for url in detailURLs {
                do {
                    let details = try await interactor.getPokemonDetails(url: url)
                    pokemonDetails.append(details)
                } catch {
                    self.errorMessage = "Error fetching Pokémon details: \(error.localizedDescription)"
                    print("Error fetching Pokémon details for URL \(url): \(error.localizedDescription)")
                }
            }

        } catch {
            self.errorMessage = "Error fetching Pokémon data: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// Load details of a specific Pokémon
    func fetchPokemonDetails(url: String) async -> PokemonDetailsResponse? {
        isLoading = true
        guard let url = URL(string: url) else {
            print("Invalid URL: \(url)")
            return nil
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let details = try JSONDecoder().decode(PokemonDetailsResponse.self, from: data)
            isLoading = false
            return details
        } catch {
            print("Error fetching Pokémon details: \(error.localizedDescription)")
            self.errorMessage = "Error fetching Pokémon data: \(error.localizedDescription)"
            isLoading = false
            return nil
        }
    }
}
