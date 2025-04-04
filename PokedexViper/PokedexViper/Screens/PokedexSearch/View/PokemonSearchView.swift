//
//  PokemonSearchView.swift
//  PokedexViper
//
//  Created by Izabela Reis on 9/12/24.
//

import SwiftUI

struct PokemonSearchView<T: PokemonSearchPresenterProtocol>: View {
    @ObservedObject var presenter: T
    @State private var searchText: String = ""

    var body: some View {
        NavigationView {
            VStack {
                if presenter.isLoading {
                    LoadingView()
                } else if let result = presenter.pokemonList?.results {
                    headerView
                    pokemonListView(result)
                } else if presenter.errorMessage != nil {
                    errorStateView
                }
            }
            .alert(isPresented: .constant(presenter.errorMessage != nil)) {
                Alert(title: Text("Erro"),
                      message: Text(presenter.errorMessage ?? ""),
                      dismissButton: .default(Text("Ok")))
            }
        }
    }
        
    private var headerView: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                Text("Pokédex")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.gray)

                    TextField("Search Pokémon", text: $searchText)
                        .padding(4)
                        .background(Color.white)
                    Spacer()

                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark")
                                .foregroundStyle(.gray)
                        }
                    } else {
                        micButton
                    }
                }
                .padding(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                .background(Color.white)
                .cornerRadius(20)
            }
            .padding(EdgeInsets(top: 0, leading: 12, bottom: 16, trailing: 12))
            .background(Color(red: 220/255, green: 10/255, blue: 45/255))
            .frame(maxWidth: .infinity)
        }
    }

    private var micButton: some View {
        Button {
            // to-do
        }  label: {
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 34, height: 34)
                Image(systemName: "mic")
                    .foregroundStyle(.gray)
                    .font(.system(size: 18))
            }
        }
    }

    @ViewBuilder
    private func pokemonListView(_ pokemonResults: [PokemonResults]) -> some View {
        let columns = Array(repeating: GridItem(.flexible()), count: 3)
        let filteredResults = pokemonResults.filter {
            searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText)
        }

        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(filteredResults, id: \.name) { result in
                    if let pokemonCard = pokemonCardView(for: result) {
                        pokemonCard
                    }
                }
            }
            .padding()
        }
    }

    private func pokemonCardView(for result: PokemonResults) -> AnyView? {
        guard let pokemonID = extractPokemonID(from: result.url) else { return nil }

        let imageURL = presenter.pokemonDetails
            .first(where: { String($0.id) == pokemonID })?
            .sprites.other.officialArtwork.frontDefault

        return AnyView(
            NavigationLink(destination: PokemonDetailView(presenter: presenter, pokemonName: result.name, url: result.url)) {
                ZStack {
                    GeometryReader { geometry in
                        VStack(spacing: 0) {
                            Color(red: 239/255, green: 239/255, blue: 239/255)
                                .frame(height: geometry.size.height / 2)
                            Color.white
                                .frame(height: geometry.size.height / 2)
                        }
                    }
                    .cornerRadius(10)

                    VStack {
                        AsyncImage(url: URL(string: imageURL ?? "")) { image in
                            image
                                .resizable()
                                .scaledToFit()
                                .frame(width: 72, height: 72)
                        } placeholder: {
                            LoadingView(isLoadingIndicator: true)
                        }

                        Text(result.name.capitalized)
                            .font(.caption)
                            .foregroundStyle(.black)
                    }
                    .frame(width: 104, height: 108)
                }
                .frame(width: 104, height: 108)
                .shadow(radius: 10)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.black.opacity(0.3), lineWidth: 1)
                )
            }
        )
    }

    private func extractPokemonID(from urlString: String) -> String? {
        guard let lastComponent = urlString.split(separator: "/").last else {
            return nil
        }
        return String(lastComponent)
    }

    private var errorStateView: some View {
        VStack(alignment: .center, spacing: 20) {
            Image("emptyStateImage")
                .resizable()
                .scaledToFit()
                .frame(width: 70, height: 70)
            Text(!searchText.isEmpty ? "No data found." : Localizable.title)
                .font(.headline)
                .multilineTextAlignment(.center)
            Text(!searchText.isEmpty ? "Try another search" : Localizable.errorMessage)
                .font(.subheadline)
                .foregroundStyle(.gray)
                .multilineTextAlignment(.center)
        }
        .padding(16)
    }
}

extension Binding where Value == String? {
    var isNotNil: Binding<Bool> {
        Binding<Bool>(
            get: { self.wrappedValue != nil },
            set: { _ in }
        )
    }
}

// MARK: - Preview
struct PokemonListView_Previews: PreviewProvider {
    static var previews: some View {
        let mockService = MockPokemonService()
        let interactor = PokemonSearchInteractor(pokemonService: mockService)
        let presenter = PokemonSearchPresenter(interactor: interactor)
        return PokemonSearchView(presenter: presenter)
            .environmentObject(presenter)
    }
}
