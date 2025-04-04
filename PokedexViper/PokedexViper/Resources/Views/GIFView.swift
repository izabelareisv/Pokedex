//
//  GIFView.swift
//  PokedexViper
//
//  Created by Izabela Reis on 9/15/24.
//

import SwiftUI
import WebKit

// UIViewRepresentable para exibir GIF com WKWebView
struct GIFView: UIViewRepresentable {
    let gifName: String

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.isUserInteractionEnabled = false // Desabilita a interação para que o GIF seja apenas visualizado
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        if let filePath = Bundle.main.path(forResource: gifName, ofType: "gif") {
            let gifURL = URL(fileURLWithPath: filePath)
            let gifData = try? Data(contentsOf: gifURL)
            uiView.load(gifData!, mimeType: "image/gif", characterEncodingName: "", baseURL: gifURL.deletingLastPathComponent())
        }
    }
}
