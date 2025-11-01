//
//  Models.swift
//  PushPuzzle-iOS
//
//  Created by Tom Hartnett on 10/27/25.
//

import Foundation

struct AllLevels: Codable {
    let levels: [Level]
}

struct Level: Codable, Identifiable {
    let id: UUID
    let rows: [[Int]]

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        self.rows = try container.decode([[Int]].self, forKey: .rows)
    }
}

func loadLevels() throws -> AllLevels? {
    guard let url = Bundle.main.url(forResource: "all-levels", withExtension: "json") else {
        return nil
    }

    let data = try Data(contentsOf: url)

    let decoder = JSONDecoder()
    let allLevels = try decoder.decode(AllLevels.self, from: data)

    for (index, level) in allLevels.levels.enumerated() {
        let rowLength = level.rows.first?.count ?? 0
        let rowCount = level.rows.count
        print("Level \(index): \(rowLength)x\(rowCount)")
    }

    return allLevels
}
