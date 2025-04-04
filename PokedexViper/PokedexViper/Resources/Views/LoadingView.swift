//
//  LoadingView.swift
//  PokedexViper
//
//  Created by Izabela Reis on 9/15/24.
//

import SwiftUI

struct LoadingView: View {
    @State private var isRotating = false
    var isLoadingIndicator: Bool = false
    
    var body: some View {
        ZStack {
            backgroundColor
                .edgesIgnoringSafeArea(.all)
            
            Image(.iconPokeball)
                .resizable()
                .frame(width: 50, height: 50)
                .background(Color.white.opacity(0.8))
                .cornerRadius(60)
                .shadow(color: Color.black.opacity(0.5), radius: 10, x: 0, y: 5)
                .clipShape(Circle())
                .rotationEffect(Angle(degrees: isRotating ? 360 : 0))
                .onAppear {
                    isRotating = true
                }
                .onDisappear {
                    isRotating = false
                }
                .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: isRotating)
        }
    }
    
    private var backgroundColor: Color {
        isLoadingIndicator ? Color.white : Color.black.opacity(0.4)
    }
}

// MARK: - Preview
struct LoadingView_Previews: PreviewProvider {
    static var previews: some View {
        return LoadingView()
    }
}
