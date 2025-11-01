//
//  ContentView.swift
//  PushPuzzle-iOS
//
//  Created by Tom Hartnett on 10/27/25.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        GameViewControllerRepresentable()
            .ignoresSafeArea()
    }
}

struct GameViewControllerRepresentable: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> GameViewController {
        return GameViewController()
    }

    func updateUIViewController(_ uiViewController: GameViewController, context: Context) {
        // No updates needed
    }
}

#Preview {
    ContentView()
}
