//
//  ContentView.swift
//  PushPuzzle-iOS
//
//  Created by Tom Hartnett on 10/27/25.
//

import SwiftUI

struct ContentView: View {
    @State private var levels: [Level] = []
    @State private var puzzleCount = 0

    var body: some View {
        ScrollView {
            VStack {
                ForEach(levels) { level in
                    PuzzleView(level)
                        .border(.white)
                        .padding(.vertical)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .background(.black)
        .onAppear {
            do {
                let allLevels = try loadLevels()
                levels = allLevels?.levels ?? []
            } catch {
                print(error)
            }
        }
    }
}

struct PuzzleView: View {
    var rows: [String] = []

    init(_ puzzle: Level) {
        for row in puzzle.rows {
            let line = row.map { num in
                switch num {
                case 0:
                    return " "
                case 1:
                    return "🪨"
                case 2:
                    return "🔳"
                case 3:
                    return "💎"
                case 4:
                    return "👴🏻"
                case 5:
                    return "⬜️"
                default:
                    return "?"
                }
            }.joined()
            rows.append(line)
        }
    }

    var body: some View {
        VStack(alignment: .leading) {
            ForEach(rows, id: \.self) { row in
                HStack {
                    let chs = Array(row)
                    ForEach(chs, id: \.self) { ch in
                        Text(String(ch))
                            .frame(width: 24, height: 24)
                            .minimumScaleFactor(0.5)
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
