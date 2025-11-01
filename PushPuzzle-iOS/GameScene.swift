//
//  GameScene.swift
//  PushPuzzle-iOS
//
//  Created by Tom Hartnett on 10/27/25.
//

import SpriteKit

class GameScene: SKScene {
    let tileSize: CGFloat = 48

    var level: Level?
    var playerNode: SKSpriteNode?
    var playerGridPosition = (x: 0, y: 0)

    // Track diamonds and targets
    var diamondNodes: [String: SKSpriteNode] = [:] // Key: "x,y"
    var targetPositions: Set<String> = [] // Set of "x,y" for target tiles

    var boardStartX: CGFloat = 0
    var boardStartY: CGFloat = 0

    override func didMove(to view: SKView) {
        // Set scene size to match view
        size = view.bounds.size
        backgroundColor = .black

        // Load first level
        if let allLevels = try? loadLevels(),
           let firstLevel = allLevels.levels.first {
            self.level = firstLevel
            setupLevel(firstLevel)
        }

        // Setup swipe gestures
        setupGestureRecognizers(view: view)
    }

    func setupLevel(_ level: Level) {
        // Clear existing nodes
        removeAllChildren()
        diamondNodes.removeAll()
        targetPositions.removeAll()

        let rows = level.rows
        let rowCount = rows.count
        let columnCount = rows.first?.count ?? 0

        // Calculate board size and position
        let boardWidth = CGFloat(columnCount) * tileSize
        let boardHeight = CGFloat(rowCount) * tileSize
        boardStartX = (size.width - boardWidth) / 2
        boardStartY = (size.height - boardHeight) / 2

        // Create tiles
        for (rowIndex, row) in rows.enumerated() {
            for (colIndex, tileType) in row.enumerated() {
                let x = boardStartX + CGFloat(colIndex) * tileSize + tileSize / 2
                let y = size.height - (boardStartY + CGFloat(rowIndex) * tileSize + tileSize / 2)
                let position = CGPoint(x: x, y: y)

                switch tileType {
                case 0: // Empty
                    break

                case 1: // Wall
                    let wall = createTile(at: position, color: .gray, text: "🪨")
                    addChild(wall)

                case 2, 5: // Target (floor or target tile)
                    let target = createTile(at: position, color: .lightGray, text: "🔳")
                    addChild(target)
                    targetPositions.insert("\(colIndex),\(rowIndex)")

                case 3: // Diamond
                    let diamond = createTile(at: position, color: .clear, text: "💎", zPosition: 5)
                    addChild(diamond)
                    diamondNodes["\(colIndex),\(rowIndex)"] = diamond

                case 4: // Player
                    playerNode = createTile(at: position, color: .clear, text: "👴🏻", zPosition: 10)
                    addChild(playerNode!)
                    playerGridPosition = (x: colIndex, y: rowIndex)

                default:
                    break
                }
            }
        }
    }

    func createTile(at position: CGPoint, color: UIColor, text: String, zPosition: CGFloat = 0) -> SKSpriteNode {
        let tile = SKSpriteNode(color: color, size: CGSize(width: tileSize - 2, height: tileSize - 2))
        tile.position = position
        tile.zPosition = zPosition

        if !text.isEmpty {
            let label = SKLabelNode(text: text)
            label.fontSize = 32
            label.verticalAlignmentMode = .center
            label.horizontalAlignmentMode = .center
            tile.addChild(label)
        }

        return tile
    }

    func setupGestureRecognizers(view: SKView) {
        // Swipe gestures for iOS
        let swipeUp = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
        swipeUp.direction = .up
        view.addGestureRecognizer(swipeUp)

        let swipeDown = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
        swipeDown.direction = .down
        view.addGestureRecognizer(swipeDown)

        let swipeLeft = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
        swipeLeft.direction = .left
        view.addGestureRecognizer(swipeLeft)

        let swipeRight = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
        swipeRight.direction = .right
        view.addGestureRecognizer(swipeRight)
    }

    @objc func handleSwipe(_ gesture: UISwipeGestureRecognizer) {
        switch gesture.direction {
        case .up:
            movePlayer(dx: 0, dy: -1)
        case .down:
            movePlayer(dx: 0, dy: 1)
        case .left:
            movePlayer(dx: -1, dy: 0)
        case .right:
            movePlayer(dx: 1, dy: 0)
        default:
            break
        }
    }

    func movePlayer(dx: Int, dy: Int) {
        guard let level = level else { return }

        let newX = playerGridPosition.x + dx
        let newY = playerGridPosition.y + dy

        // Check bounds
        guard newY >= 0 && newY < level.rows.count &&
              newX >= 0 && newX < level.rows[newY].count else {
            return
        }

        let targetTile = level.rows[newY][newX]
        let targetKey = "\(newX),\(newY)"

        // Check if there's a wall
        guard targetTile != 1 else {
            return
        }

        // Check if there's a diamond at target position (check current state, not initial level data)
        if diamondNodes[targetKey] != nil {
            // Try to push the diamond
            let diamondNewX = newX + dx
            let diamondNewY = newY + dy

            // Check bounds for diamond's new position
            guard diamondNewY >= 0 && diamondNewY < level.rows.count &&
                  diamondNewX >= 0 && diamondNewX < level.rows[diamondNewY].count else {
                return
            }

            let diamondTargetTile = level.rows[diamondNewY][diamondNewX]
            let diamondNewKey = "\(diamondNewX),\(diamondNewY)"

            // Diamond can move anywhere except walls (1) and other diamonds
            guard diamondTargetTile != 1 && diamondNodes[diamondNewKey] == nil else {
                return
            }

            // Push the diamond
            if let diamond = diamondNodes[targetKey] {
                let newDiamondPos = gridToPosition(x: diamondNewX, y: diamondNewY)
                let moveAction = SKAction.move(to: newDiamondPos, duration: 0.15)
                diamond.run(moveAction)

                // Update diamond tracking
                diamondNodes.removeValue(forKey: targetKey)
                diamondNodes[diamondNewKey] = diamond
            }
        }

        // Move player
        let newPlayerPos = gridToPosition(x: newX, y: newY)
        let moveAction = SKAction.move(to: newPlayerPos, duration: 0.15)
        playerNode?.run(moveAction)

        // Update player position
        playerGridPosition = (x: newX, y: newY)

        // Check win condition
        checkWinCondition()
    }

    func gridToPosition(x: Int, y: Int) -> CGPoint {
        let posX = boardStartX + CGFloat(x) * tileSize + tileSize / 2
        let posY = size.height - (boardStartY + CGFloat(y) * tileSize + tileSize / 2)
        return CGPoint(x: posX, y: posY)
    }

    func checkWinCondition() {
        // Check if all diamonds are on targets
        let diamondPositions = Set(diamondNodes.keys)

        if diamondPositions == targetPositions {
            // Level complete!
            let label = SKLabelNode(text: "Level Complete!")
            label.fontSize = 48
            label.fontColor = .green
            label.position = CGPoint(x: size.width / 2, y: size.height / 2)
            label.zPosition = 100
            addChild(label)

            // Fade in effect
            label.alpha = 0
            label.run(SKAction.fadeIn(withDuration: 0.5))
        }
    }
}
