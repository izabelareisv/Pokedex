//
//  SplashView.swift
//  PokedexViper
//
//  Created by Izabela Reis on 9/13/24.
//

import SwiftUI

struct SplashView: View {
    @State private var zoomIn = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .edgesIgnoringSafeArea(.all)

            Image("iconPokeball")
                .resizable()
                .accessibilityHidden(true)
                .scaledToFit()
                .scaleEffect(zoomIn ? 0.7 : 0.5)
                .frame(width: 200, height: 200)
                .onAppear {
                    guard !reduceMotion else { return }
                    withAnimation(Animation.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                        zoomIn.toggle()
                    }
                }
        }
    }
}

// MARK: - Preview
struct SplashView_Previews: PreviewProvider {
    static var previews: some View {
        return SplashView()
    }
}
