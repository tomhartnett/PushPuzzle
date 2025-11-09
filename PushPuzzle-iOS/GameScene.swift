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

    // Track boxes and targets
    var boxNodes: [String: SKSpriteNode] = [:] // Key: "x,y"
    var targetPositions: Set<String> = [] // Set of "x,y" for target tiles

    var boardStartX: CGFloat = 0
    var boardStartY: CGFloat = 0

    // Level management
    var allLevels: [Level] = []
    var currentLevelIndex = 0

    // UI Buttons
    var resetButton: SKLabelNode?
    var undoButton: SKLabelNode?
    var prevButton: SKLabelNode?
    var nextButton: SKLabelNode?
    var levelTitleLabel: SKLabelNode?
    var completionCountLabel: SKLabelNode?

    // Auto-navigation
    var autoNavigationPath: [(x: Int, y: Int)] = []
    var isAutoNavigating = false

    // Move history for undo
    struct MoveState {
        let playerPosition: (x: Int, y: Int)
        let boxFrom: (x: Int, y: Int)?
        let boxTo: (x: Int, y: Int)?
        let playerRotation: CGFloat
        let playerXScale: CGFloat
    }
    var moveHistory: [MoveState] = []

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
        // Cancel any ongoing auto-navigation
        isAutoNavigating = false
        autoNavigationPath.removeAll()

        // Clear move history
        moveHistory.removeAll()

        if let level = level {
            setupLevel(level)
            setupButtons()
        }
    }

    func setupLevel(_ level: Level) {
        // Clear existing nodes
        removeAllChildren()
        boxNodes.removeAll()
        targetPositions.removeAll()

        // Cancel any ongoing auto-navigation
        isAutoNavigating = false
        autoNavigationPath.removeAll()

        // Clear move history
        moveHistory.removeAll()

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
                    let wall = createTile(at: position, color: .clear, text: "🟫")
                    addChild(wall)

                case 2: // Target (floor or target tile)
                    let target = createTile(at: position, color: .clear, text: "🅇")
                    addChild(target)
                    targetPositions.insert("\(colIndex),\(rowIndex)")

                case 3: // Box
                    let box = createTile(at: position, color: .clear, text: "📦", zPosition: 5)
                    addChild(box)
                    boxNodes["\(colIndex),\(rowIndex)"] = box

                case 4: // Player
                    playerNode = createTile(at: position, color: .clear, text: "🚜", zPosition: 10)
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
            label.fontSize = tileSize * 0.90
            label.verticalAlignmentMode = .center
            label.horizontalAlignmentMode = .center
            tile.addChild(label)
        }

        return tile
    }

    func setupButtons() {
        // Remove old buttons if they exist
        resetButton?.removeFromParent()
        undoButton?.removeFromParent()
        prevButton?.removeFromParent()
        nextButton?.removeFromParent()
        levelTitleLabel?.removeFromParent()
        completionCountLabel?.removeFromParent()

        // Position UI at top with safe spacing below dynamic island
        // Dynamic island is about 37pt tall, so start at least 60pt from top
        let buttonY: CGFloat = size.height - 150

        // Level title (highest element)
        let titleY: CGFloat = size.height - 80
        levelTitleLabel = SKLabelNode(text: level?.name ?? "")
        levelTitleLabel?.fontSize = 28
        levelTitleLabel?.fontName = "Helvetica-Bold"
        levelTitleLabel?.fontColor = .white
        levelTitleLabel?.position = CGPoint(x: size.width / 2, y: titleY)
        levelTitleLabel?.zPosition = 100
        addChild(levelTitleLabel!)

        // Completion count (below level title)
        let completionY: CGFloat = size.height - 110
        let completionCount = getCompletionCount(for: currentLevelIndex)
        let completionText = completionCount == 1 ? "Completed 1 time" : "Completed \(completionCount) times"
        completionCountLabel = SKLabelNode(text: completionText)
        completionCountLabel?.fontSize = 16
        completionCountLabel?.fontName = "Helvetica-Bold"
        completionCountLabel?.fontColor = .lightGray
        completionCountLabel?.position = CGPoint(x: size.width / 2, y: completionY)
        completionCountLabel?.zPosition = 100
        addChild(completionCountLabel!)

        // Undo button (center-left)
        undoButton = SKLabelNode(text: "Undo")
        undoButton?.fontSize = 20
        undoButton?.fontName = "Helvetica-Bold"
        undoButton?.fontColor = !moveHistory.isEmpty ? .white : .gray
        undoButton?.position = CGPoint(x: size.width / 2 - 70, y: buttonY)
        undoButton?.name = "undoButton"
        undoButton?.zPosition = 100
        addChild(undoButton!)

        // Reset button (center-right)
        resetButton = SKLabelNode(text: "Reset")
        resetButton?.fontSize = 20
        resetButton?.fontName = "Helvetica-Bold"
        resetButton?.fontColor = .white
        resetButton?.position = CGPoint(x: size.width / 2 + 70, y: buttonY)
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
            if node.name == "undoButton" && !moveHistory.isEmpty {
                undoLastMove()
            } else if node.name == "resetButton" {
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

        // Long-press gesture for auto-navigation
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPress.minimumPressDuration = 0.5
        view.addGestureRecognizer(longPress)
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

    func updatePlayerOrientation(dx: Int, dy: Int) {
        guard let player = playerNode else { return }

        // Update player rotation based on movement direction
        if dx > 0 {
            // Moving right - flip horizontally
            player.xScale = -1
            player.zRotation = 0
        } else if dx < 0 {
            // Moving left - default orientation
            player.xScale = 1
            player.zRotation = 0
        } else if dy < 0 {
            // Moving up - rotate -90 degrees
            player.xScale = 1
            player.zRotation = -.pi / 2
        } else if dy > 0 {
            // Moving down - rotate 90 degrees
            player.xScale = 1
            player.zRotation = .pi / 2
        }
    }

    func movePlayer(dx: Int, dy: Int) {
        guard let level = level else { return }

        // Cancel auto-navigation if manually moving
        if isAutoNavigating {
            isAutoNavigating = false
            autoNavigationPath.removeAll()
        }

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

        // Prepare move state for undo
        var boxFromPos: (x: Int, y: Int)? = nil
        var boxToPos: (x: Int, y: Int)? = nil

        // Check if there's a box at target position (check current state, not initial level data)
        if boxNodes[targetKey] != nil {
            // Try to push the box
            let boxNewX = newX + dx
            let boxNewY = newY + dy

            // Check bounds for box's new position
            guard boxNewY >= 0 && boxNewY < level.rows.count &&
                  boxNewX >= 0 && boxNewX < level.rows[boxNewY].count else {
                return
            }

            let boxTargetTile = level.rows[boxNewY][boxNewX]
            let boxNewKey = "\(boxNewX),\(boxNewY)"

            // Box can move anywhere except walls (1) and other boxes
            guard boxTargetTile != 1 && boxNodes[boxNewKey] == nil else {
                return
            }

            // Record box movement for undo
            boxFromPos = (x: newX, y: newY)
            boxToPos = (x: boxNewX, y: boxNewY)

            // Push the box
            if let box = boxNodes[targetKey] {
                let newBoxPos = gridToPosition(x: boxNewX, y: boxNewY)
                let moveAction = SKAction.move(to: newBoxPos, duration: 0.15)
                box.run(moveAction)

                // Update box tracking
                boxNodes.removeValue(forKey: targetKey)
                boxNodes[boxNewKey] = box
            }
        }

        // Save state to history (before updating player position and orientation)
        let moveState = MoveState(
            playerPosition: playerGridPosition,
            boxFrom: boxFromPos,
            boxTo: boxToPos,
            playerRotation: playerNode?.zRotation ?? 0,
            playerXScale: playerNode?.xScale ?? 1
        )
        moveHistory.append(moveState)

        // Update player orientation based on movement direction
        updatePlayerOrientation(dx: dx, dy: dy)

        // Move player
        let newPlayerPos = gridToPosition(x: newX, y: newY)
        let moveAction = SKAction.move(to: newPlayerPos, duration: 0.15)
        playerNode?.run(moveAction)

        // Update player position
        playerGridPosition = (x: newX, y: newY)

        // Update undo button state
        undoButton?.fontColor = !moveHistory.isEmpty ? .white : .gray

        // Check win condition
        checkWinCondition()
    }

    func gridToPosition(x: Int, y: Int) -> CGPoint {
        let posX = boardStartX + CGFloat(x) * tileSize + tileSize / 2
        let posY = size.height - (boardStartY + CGFloat(y) * tileSize + tileSize / 2)
        return CGPoint(x: posX, y: posY)
    }

    func getCompletionCount(for levelIndex: Int) -> Int {
        let key = "level_\(levelIndex)_completions"
        return UserDefaults.standard.integer(forKey: key)
    }

    func incrementCompletionCount(for levelIndex: Int) {
        let key = "level_\(levelIndex)_completions"
        let currentCount = UserDefaults.standard.integer(forKey: key)
        UserDefaults.standard.set(currentCount + 1, forKey: key)
    }

    func checkWinCondition() {
        // Check if all boxes are on targets
        let boxPositions = Set(boxNodes.keys)

        if boxPositions == targetPositions {
            // Increment completion count for this level
            incrementCompletionCount(for: currentLevelIndex)

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

    // MARK: - Undo

    func undoLastMove() {
        guard !moveHistory.isEmpty else { return }

        // Cancel any ongoing auto-navigation
        isAutoNavigating = false
        autoNavigationPath.removeAll()

        // Get the last state
        let lastState = moveHistory.removeLast()

        // Restore box position if a box was moved
        if let boxFrom = lastState.boxFrom, let boxTo = lastState.boxTo {
            let boxToKey = "\(boxTo.x),\(boxTo.y)"
            let boxFromKey = "\(boxFrom.x),\(boxFrom.y)"

            // Move the box back
            if let box = boxNodes[boxToKey] {
                let oldBoxPos = gridToPosition(x: boxFrom.x, y: boxFrom.y)
                let moveAction = SKAction.move(to: oldBoxPos, duration: 0.15)
                box.run(moveAction)

                // Update box tracking
                boxNodes.removeValue(forKey: boxToKey)
                boxNodes[boxFromKey] = box
            }
        }

        // Restore player position and orientation
        let oldPlayerPos = gridToPosition(x: lastState.playerPosition.x, y: lastState.playerPosition.y)
        let moveAction = SKAction.move(to: oldPlayerPos, duration: 0.15)
        playerNode?.run(moveAction)

        // Restore player orientation
        playerNode?.zRotation = lastState.playerRotation
        playerNode?.xScale = lastState.playerXScale

        // Update player position
        playerGridPosition = lastState.playerPosition

        // Update undo button color
        undoButton?.fontColor = !moveHistory.isEmpty ? .white : .gray
    }

    // MARK: - Auto-navigation

    @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        guard !isAutoNavigating else { return }

        let location = gesture.location(in: gesture.view)
        guard let gridPos = positionToGrid(point: location) else { return }

        // Find path and start auto-navigation
        if let path = findPath(from: playerGridPosition, to: gridPos) {
            autoNavigationPath = path
            isAutoNavigating = true
            moveAlongPath()
        }
    }

    func positionToGrid(point: CGPoint) -> (x: Int, y: Int)? {
        guard let level = level else { return nil }

        // Convert view coordinates to scene coordinates
        guard let view = self.view else { return nil }
        let scenePoint = convertPoint(fromView: point)

        // Calculate grid position
        let relativeX = scenePoint.x - boardStartX
        let relativeY = size.height - scenePoint.y - boardStartY

        let gridX = Int(relativeX / tileSize)
        let gridY = Int(relativeY / tileSize)

        // Validate bounds
        guard gridY >= 0 && gridY < level.rows.count &&
              gridX >= 0 && gridX < level.rows[gridY].count else {
            return nil
        }

        return (x: gridX, y: gridY)
    }

    func findPath(from start: (x: Int, y: Int), to end: (x: Int, y: Int)) -> [(x: Int, y: Int)]? {
        guard let level = level else { return nil }

        // Check if target is walkable
        let targetTile = level.rows[end.y][end.x]
        let targetKey = "\(end.x),\(end.y)"

        // Can't navigate to walls or boxes
        guard targetTile != 1 && boxNodes[targetKey] == nil else {
            return nil
        }

        // BFS pathfinding
        var queue: [(pos: (x: Int, y: Int), path: [(x: Int, y: Int)])] = [(start, [])]
        var visited = Set<String>()
        visited.insert("\(start.x),\(start.y)")

        let directions = [(0, -1), (0, 1), (-1, 0), (1, 0)] // up, down, left, right

        while !queue.isEmpty {
            let current = queue.removeFirst()
            let pos = current.pos
            let path = current.path

            // Check if we reached the goal
            if pos.x == end.x && pos.y == end.y {
                return path
            }

            // Explore neighbors
            for dir in directions {
                let newX = pos.x + dir.0
                let newY = pos.y + dir.1
                let key = "\(newX),\(newY)"

                // Check bounds
                guard newY >= 0 && newY < level.rows.count &&
                      newX >= 0 && newX < level.rows[newY].count else {
                    continue
                }

                // Skip if already visited
                guard !visited.contains(key) else {
                    continue
                }

                let tile = level.rows[newY][newX]

                // Can only walk on empty tiles (not walls, not boxes)
                guard tile != 1 && boxNodes[key] == nil else {
                    continue
                }

                visited.insert(key)
                var newPath = path
                newPath.append((x: newX, y: newY))
                queue.append(((x: newX, y: newY), newPath))
            }
        }

        return nil // No path found
    }

    func moveAlongPath() {
        guard !autoNavigationPath.isEmpty else {
            isAutoNavigating = false
            return
        }

        let nextPos = autoNavigationPath.removeFirst()
        let dx = nextPos.x - playerGridPosition.x
        let dy = nextPos.y - playerGridPosition.y

        // Update player orientation based on movement direction
        updatePlayerOrientation(dx: dx, dy: dy)

        // Move player
        let newPlayerPos = gridToPosition(x: nextPos.x, y: nextPos.y)
        let moveAction = SKAction.move(to: newPlayerPos, duration: 0.15)

        playerNode?.run(moveAction) { [weak self] in
            guard let self = self else { return }

            // Update player position
            self.playerGridPosition = nextPos

            // Continue moving along path
            if self.isAutoNavigating {
                self.moveAlongPath()
            }
        }
    }

    // MARK: - Orientation Handling

    struct GameState {
        let playerPosition: (x: Int, y: Int)
        let boxPositions: [(x: Int, y: Int)]
        let moveHistory: [MoveState]
        let isAutoNavigating: Bool
        let autoNavigationPath: [(x: Int, y: Int)]
    }

    func saveGameState() -> GameState {
        // Convert boxNodes dictionary to array of positions
        let boxPositions = boxNodes.keys.compactMap { key -> (x: Int, y: Int)? in
            let components = key.split(separator: ",")
            guard components.count == 2,
                  let x = Int(components[0]),
                  let y = Int(components[1]) else {
                return nil
            }
            return (x: x, y: y)
        }

        return GameState(
            playerPosition: playerGridPosition,
            boxPositions: boxPositions,
            moveHistory: moveHistory,
            isAutoNavigating: isAutoNavigating,
            autoNavigationPath: autoNavigationPath
        )
    }

    func handleOrientationChange(newSize: CGSize) {
        guard let level = level else { return }

        // Save current game state
        let savedState = saveGameState()

        // Update scene size
        size = newSize

        // Recalculate layout without recreating nodes
        recalculateLayout()

        // Restore move history and navigation state
        moveHistory = savedState.moveHistory
        isAutoNavigating = savedState.isAutoNavigating
        autoNavigationPath = savedState.autoNavigationPath

        // Restore buttons
        setupButtons()
    }

    func recalculateLayout() {
        guard let level = level else { return }

        let rows = level.rows
        let rowCount = rows.count
        let columnCount = rows.first?.count ?? 0

        // Recalculate tile size to fit the screen with padding
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

        // Remove and recreate static tiles (walls and targets)
        // Collect nodes to remove
        var nodesToRemove: [SKNode] = []
        for node in children {
            guard let sprite = node as? SKSpriteNode,
                  let label = sprite.children.first as? SKLabelNode else {
                continue
            }

            // Remove walls and targets (but not player or boxes or buttons)
            if label.text == "🟫" || label.text == "🅇" {
                nodesToRemove.append(sprite)
            }
        }

        // Remove the collected nodes
        for node in nodesToRemove {
            node.removeFromParent()
        }

        // Recreate static tiles
        for (rowIndex, row) in rows.enumerated() {
            for (colIndex, tileType) in row.enumerated() {
                let x = boardStartX + CGFloat(colIndex) * tileSize + tileSize / 2
                let y = size.height - (boardStartY + CGFloat(rowIndex) * tileSize + tileSize / 2)
                let position = CGPoint(x: x, y: y)

                switch tileType {
                case 1: // Wall
                    let wall = createTile(at: position, color: .clear, text: "🟫")
                    addChild(wall)

                case 2: // Target
                    let target = createTile(at: position, color: .clear, text: "🅇")
                    addChild(target)

                default:
                    break
                }
            }
        }

        // Reposition player
        if let player = playerNode {
            player.position = gridToPosition(x: playerGridPosition.x, y: playerGridPosition.y)
            player.size = CGSize(width: tileSize - 2, height: tileSize - 2)
            // Update emoji size
            if let label = player.children.first as? SKLabelNode {
                label.fontSize = tileSize * 0.90
            }
        }

        // Reposition all boxes
        for (key, box) in boxNodes {
            let components = key.split(separator: ",")
            if components.count == 2,
               let x = Int(components[0]),
               let y = Int(components[1]) {
                box.position = gridToPosition(x: x, y: y)
                box.size = CGSize(width: tileSize - 2, height: tileSize - 2)
                // Update emoji size
                if let label = box.children.first as? SKLabelNode {
                    label.fontSize = tileSize * 0.90
                }
            }
        }
    }
}
