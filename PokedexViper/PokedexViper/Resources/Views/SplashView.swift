//
//  SplashView.swift
//  PokedexViper
//
//  Created by Izabela Reis on 9/13/24.
//

import SwiftUI

struct SplashView: View {
    @State private var zoomIn = false

    var body: some View {
        ZStack {
            Color.white
                .edgesIgnoringSafeArea(.all)

            Image(uiImage: UIImage(named: "iconPokeball")!)
                .resizable()
                .scaledToFit()
                .scaleEffect(zoomIn ? 0.7 : 0.5)
                .frame(width: 200, height: 200)
                .onAppear {
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
