import SwiftUI

struct PokemonDetailView<T: PokemonSearchPresenterProtocol>: View {
    let presenter: T
    let pokemonName: String
    let url: String

    @Environment(\.dismiss) private var dismiss

    private var pokemonColor: Color {
        guard let firstType = presenter.pokemonDetails
            .first(where: { $0.name.lowercased() == pokemonName.lowercased() })?
            .types.first?.type.name else {
                return .gray
        }
        return TagColor(name: firstType).color
    }

    var body: some View {
        ZStack {
            backgroundLayout
            content
        }
        .navigationBarTitleDisplayMode(.large)
        .navigationBarBackButtonHidden(true)
        .toolbar { navigationBarToolbar }
    }

    // MARK: - Background Layout (Top color + bottom white)
    private var backgroundLayout: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                Color(pokemonColor)
                    .frame(height: geometry.size.height * 0.4)

                Color.white
                    .frame(height: geometry.size.height * 0.7)
                    .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                    .edgesIgnoringSafeArea(.bottom)
            }
            .edgesIgnoringSafeArea(.all)
        }
    }

    // MARK: - Main Content
    private var content: some View {
        VStack {
            if let pokemonDetail = presenter.pokemonDetails
                .first(where: { $0.name.lowercased() == pokemonName.lowercased() }) {
                
                pokemonImage(pokemonDetail)
                tagView(pokemonDetail)
                infoView(pokemonDetail, pokemonColor)
                baseStatsView(pokemonDetail, pokemonColor)
                    .padding(.horizontal, 12)
                    .scrollIndicators(.hidden)
            } else {
                LoadingView(isLoadingIndicator: true)
            }
        }
    }

    // MARK: - Navigation Bar
    private var navigationBarToolbar: some ToolbarContent {
        return Group {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .foregroundStyle(.white)
                }
            }

            ToolbarItem(placement: .principal) {
                Text(pokemonName.capitalized)
                    .font(.largeTitle)
                    .bold()
                    .foregroundStyle(.white)
            }
        }
    }

    // MARK: - Pokémon Image
    @ViewBuilder
    private func pokemonImage(_ detail: PokemonDetailsResponse) -> some View {
        if let imageUrl = URL(string: detail.sprites.other.officialArtwork.frontDefault) {
            AsyncImage(url: imageUrl) { image in
                image
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 200)
            } placeholder: {
                LoadingView(isLoadingIndicator: true)
            }
        }
    }
}

// MARK: - Tag View (Type badges)
@ViewBuilder
private func tagView(_ detail: PokemonDetailsResponse) -> some View {
    HStack(spacing: 24) {
        ForEach(detail.types.prefix(2), id: \.type.url) { typeInfo in
            Text(typeInfo.type.name.capitalized)
                .font(.system(size: 18))
                .padding(8)
                .background(TagColor(name: typeInfo.type.name).color)
                .foregroundStyle(.white)
                .bold()
                .cornerRadius(20)
        }
    }
}

// MARK: - Info View (Weight, Height, Moves)
@ViewBuilder
private func infoView(_ detail: PokemonDetailsResponse, _ color: Color) -> some View {
    VStack {
        Text("About")
            .font(.system(size: 18))
            .padding(8)
            .foregroundStyle(color)
            .bold()
            .italic()

        HStack(spacing: 24) {
            infoItem(icon: "iconWeight", text: "\(detail.weight) kg", label: "Weight")
            divider
            infoItem(icon: "iconWeight", text: "\(detail.height) m", label: "Height")
            divider
            moveItem(detail.moves)
        }
    }
}

@ViewBuilder
private func infoItem(icon: String, text: String, label: String) -> some View {
    VStack(spacing: 0) {
        HStack(spacing: 0) {
            Image(icon)
                .resizable()
                .frame(width: 16, height: 16)
                .background(Color.white.opacity(0.8))
                .cornerRadius(60)
            Text(text)
                .font(.system(size: 14))
                .padding(8)
                .bold()
        }
        Text(label)
            .font(.system(size: 14))
            .foregroundStyle(.gray.opacity(0.9))
            .padding(8)
            .bold()
    }
}

@ViewBuilder
private func moveItem(_ moves: [Move]) -> some View {
    VStack(spacing: 0) {
        ForEach(moves.prefix(2), id: \.move.name) { move in
            Text(move.move.name.capitalized)
                .font(.system(size: 14))
                .bold()
        }
        Text("Moves")
            .foregroundStyle(.gray.opacity(0.9))
            .font(.system(size: 14))
            .bold()
            .padding(8)
            .padding(.top, 5)
    }
}

// MARK: - Divider
private var divider: some View {
    Rectangle()
        .frame(width: 1, height: 50)
        .foregroundStyle(.gray.opacity(0.5))
}

// MARK: - Base Stats View (Stat bars)
@ViewBuilder
private func baseStatsView(_ detail: PokemonDetailsResponse, _ color: Color) -> some View {
    VStack {
        Text("Base Stats")
            .font(.system(size: 18))
            .foregroundStyle(color)
            .bold()
            .italic()
            .padding(.top, 10)

        VStack(spacing: 0) {
            ForEach(detail.stats, id: \.stat.name) { stat in
                VStack(spacing: 0) {
                    HStack {
                        Text("\(stat.baseStat)")
                            .font(.system(size: 14))
                            .foregroundStyle(.gray)
                            .padding(.trailing, 20)

                        let barWidth: CGFloat = 255
                        let normalizedWidth = CGFloat(stat.baseStat) / 255.0 * barWidth

                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(color.opacity(0.3))
                                .frame(width: barWidth, height: 10)
                                .cornerRadius(5)

                            Rectangle()
                                .fill(color)
                                .frame(width: normalizedWidth, height: 10)
                                .cornerRadius(5)
                        }
                        .frame(height: 10)
                    }

                    Text(stat.stat.name.capitalized)
                        .font(.system(size: 14))
                        .foregroundStyle(.gray)
                }
                .padding(.bottom, 8)
            }
        }
    }
}

// MARK: - Preview
struct PokemonDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let mockService = MockPokemonService()
        let interactor = PokemonSearchInteractor(pokemonService: mockService)
        let presenter = PokemonSearchPresenter(interactor: interactor)
        return PokemonDetailView(presenter: presenter, pokemonName: "Pikachu", url: "")
    }
}
