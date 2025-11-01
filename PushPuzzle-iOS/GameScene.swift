//
//  GameScene.swift
//  PushPuzzle-iOS
//
//  Created by Tom Hartnett on 10/27/25.
//

import SpriteKit

class GameScene: SKScene {
    var tileSize: CGFloat = 48

    var level: Level?
    var playerNode: SKSpriteNode?
    var playerGridPosition = (x: 0, y: 0)

    // Track diamonds and targets
    var diamondNodes: [String: SKSpriteNode] = [:] // Key: "x,y"
    var targetPositions: Set<String> = [] // Set of "x,y" for target tiles

    var boardStartX: CGFloat = 0
    var boardStartY: CGFloat = 0

    // Level management
    var allLevels: [Level] = []
    var currentLevelIndex = 0

    // UI Buttons
    var resetButton: SKLabelNode?
    var prevButton: SKLabelNode?
    var nextButton: SKLabelNode?
    var levelTitleLabel: SKLabelNode?

    override func didMove(to view: SKView) {
        // Set scene size to match view
        size = view.bounds.size
        backgroundColor = .black

        // Load all levels
        if let levels = try? loadLevels() {
            allLevels = levels.levels
            if !allLevels.isEmpty {
                // Load persisted level or start at 0
                let savedLevel = UserDefaults.standard.integer(forKey: "currentLevel")
                let startLevel = savedLevel < allLevels.count ? savedLevel : 0
                loadLevel(at: startLevel)
            }
        }

        // Setup swipe gestures
        setupGestureRecognizers(view: view)
    }

    func loadLevel(at index: Int) {
        guard index >= 0 && index < allLevels.count else {
            return
        }

        currentLevelIndex = index
        level = allLevels[index]

        // Save current level
        UserDefaults.standard.set(index, forKey: "currentLevel")

        setupLevel(allLevels[index])
        setupButtons()
    }

    func resetLevel() {
        if let level = level {
            setupLevel(level)
            setupButtons()
        }
    }

    func setupLevel(_ level: Level) {
        // Clear existing nodes
        removeAllChildren()
        diamondNodes.removeAll()
        targetPositions.removeAll()

        let rows = level.rows
        let rowCount = rows.count
        let columnCount = rows.first?.count ?? 0

        // Calculate tile size to fit the screen with padding
        let padding: CGFloat = 40
        let availableWidth = size.width - padding * 2
        let availableHeight = size.height - padding * 2

        let tileSizeForWidth = availableWidth / CGFloat(columnCount)
        let tileSizeForHeight = availableHeight / CGFloat(rowCount)

        // Use the smaller of the two to ensure everything fits
        tileSize = min(tileSizeForWidth, tileSizeForHeight)

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
            // Scale font size based on tile size (about 2/3 of tile size)
            label.fontSize = tileSize * 0.67
            label.verticalAlignmentMode = .center
            label.horizontalAlignmentMode = .center
            tile.addChild(label)
        }

        return tile
    }

    func setupButtons() {
        // Remove old buttons if they exist
        resetButton?.removeFromParent()
        prevButton?.removeFromParent()
        nextButton?.removeFromParent()
        levelTitleLabel?.removeFromParent()

        // Position buttons below safe area (accounting for dynamic island)
        let buttonY = size.height - 120

        // Level title (above buttons)
        let titleY = size.height - 80
        levelTitleLabel = SKLabelNode(text: level?.name ?? "")
        levelTitleLabel?.fontSize = 28
        levelTitleLabel?.fontName = "Helvetica-Bold"
        levelTitleLabel?.fontColor = .white
        levelTitleLabel?.position = CGPoint(x: size.width / 2, y: titleY)
        levelTitleLabel?.zPosition = 100
        addChild(levelTitleLabel!)

        // Reset button (center)
        resetButton = SKLabelNode(text: "Reset")
        resetButton?.fontSize = 20
        resetButton?.fontName = "Helvetica-Bold"
        resetButton?.fontColor = .white
        resetButton?.position = CGPoint(x: size.width / 2, y: buttonY)
        resetButton?.name = "resetButton"
        resetButton?.zPosition = 100
        addChild(resetButton!)

        // Previous button (left)
        prevButton = SKLabelNode(text: "< Prev")
        prevButton?.fontSize = 20
        prevButton?.fontName = "Helvetica-Bold"
        prevButton?.fontColor = currentLevelIndex > 0 ? .white : .gray
        prevButton?.position = CGPoint(x: 60, y: buttonY)
        prevButton?.name = "prevButton"
        prevButton?.zPosition = 100
        addChild(prevButton!)

        // Next button (right)
        nextButton = SKLabelNode(text: "Next >")
        nextButton?.fontSize = 20
        nextButton?.fontName = "Helvetica-Bold"
        nextButton?.fontColor = currentLevelIndex < allLevels.count - 1 ? .white : .gray
        nextButton?.position = CGPoint(x: size.width - 60, y: buttonY)
        nextButton?.name = "nextButton"
        nextButton?.zPosition = 100
        addChild(nextButton!)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let touchedNodes = nodes(at: location)

        for node in touchedNodes {
            if node.name == "resetButton" {
                resetLevel()
            } else if node.name == "prevButton" && currentLevelIndex > 0 {
                loadLevel(at: currentLevelIndex - 1)
            } else if node.name == "nextButton" && currentLevelIndex < allLevels.count - 1 {
                loadLevel(at: currentLevelIndex + 1)
            }
        }
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

            // Fade in effect, then load next level
            label.alpha = 0
            let fadeIn = SKAction.fadeIn(withDuration: 0.5)
            let wait = SKAction.wait(forDuration: 1.0)
            let loadNext = SKAction.run { [weak self] in
                self?.loadNextLevel()
            }
            label.run(SKAction.sequence([fadeIn, wait, loadNext]))
        }
    }

    func loadNextLevel() {
        let nextIndex = currentLevelIndex + 1
        if nextIndex < allLevels.count {
            loadLevel(at: nextIndex)
        } else {
            // All levels complete
            let label = SKLabelNode(text: "All Levels Complete!")
            label.fontSize = 48
            label.fontColor = .yellow
            label.position = CGPoint(x: size.width / 2, y: size.height / 2)
            label.zPosition = 100
            addChild(label)
        }
    }
}
