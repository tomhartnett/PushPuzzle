//
//  Models.swift
//  PushPuzzle-iOS
//
//  Created by Tom Hartnett on 10/27/25.
//

import Foundation

struct AllLevels {
    let levels: [Level]
}

struct Level: Identifiable {
    let id: UUID
    let name: String
    let rows: [[Int]]

    init(name: String, rows: [[Int]]) {
        self.id = UUID()
        self.name = name
        self.rows = rows
    }
}

func loadLevels() throws -> AllLevels? {
    // Maps come from https://github.com/begoon/sokoban-maps
    guard let url = Bundle.main.url(forResource: "sokoban-maps-60-plain", withExtension: "txt") else {
        return nil
    }

    let content = try String(contentsOf: url, encoding: .utf8)
    let lines = content.components(separatedBy: .newlines)

    var levels: [Level] = []
    var i = 0

    while i < lines.count {
        let line = lines[i]

        // Look for start of level (line of asterisks)
        if line.hasPrefix("***") {
            i += 1

            // Parse header
            var mazeNumber = 0
            var sizeX = 0
            var sizeY = 0

            while i < lines.count {
                let headerLine = lines[i]

                if headerLine.hasPrefix("Maze:") {
                    mazeNumber = Int(headerLine.replacingOccurrences(of: "Maze:", with: "").trimmingCharacters(in: .whitespaces)) ?? 0
                } else if headerLine.hasPrefix("Size X:") {
                    sizeX = Int(headerLine.replacingOccurrences(of: "Size X:", with: "").trimmingCharacters(in: .whitespaces)) ?? 0
                } else if headerLine.hasPrefix("Size Y:") {
                    sizeY = Int(headerLine.replacingOccurrences(of: "Size Y:", with: "").trimmingCharacters(in: .whitespaces)) ?? 0
                } else if headerLine.isEmpty {
                    // Blank line after header, level data starts next
                    i += 1
                    break
                }

                i += 1
            }

            // Parse level data
            var levelRows: [[Int]] = []
            var rowCount = 0

            while i < lines.count && rowCount < sizeY {
                let levelLine = lines[i]

                // Stop at blank line (end of level)
                if levelLine.isEmpty {
                    break
                }

                var row: [Int] = []

                // Convert characters to tile types
                for char in levelLine {
                    let tileType: Int
                    switch char {
                    case " ":  // Empty floor (walkable)
                        tileType = 0
                    case "X":  // Wall
                        tileType = 1
                    case ".":  // Target
                        tileType = 2
                    case "*":  // Box
                        tileType = 3
                    case "@":  // Player
                        tileType = 4

                    default:
                        tileType = 0
                    }
                    row.append(tileType)
                }

                // Pad row to sizeX if needed
                while row.count < sizeX {
                    row.append(0)
                }

                levelRows.append(row)
                rowCount += 1
                i += 1
            }

            // Create level
            if !levelRows.isEmpty {
                let level = Level(name: "Level \(mazeNumber)", rows: levelRows)
                levels.append(level)

                print("Loaded Level \(mazeNumber): \(sizeX)x\(sizeY)")
            }
        }

        i += 1
    }

    return AllLevels(levels: levels)
}
