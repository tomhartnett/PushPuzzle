//
//  GameViewController.swift
//  PushPuzzle-iOS
//
//  Created by Tom Hartnett on 10/27/25.
//

import UIKit
import SpriteKit

class GameViewController: UIViewController {
    var skView: SKView!
    var gameScene: GameScene!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Create and configure the SKView
        skView = SKView(frame: view.bounds)
        skView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(skView)

        // Create and configure the game scene
        gameScene = GameScene()
        gameScene.scaleMode = .resizeFill

        // Present the scene
        skView.presentScene(gameScene)

        // Optional: Show FPS and node count for debugging
        skView.showsFPS = true
        skView.showsNodeCount = true
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()

        // Handle rotation by updating the scene size and re-rendering
        if gameScene.size != view.bounds.size {
            gameScene.handleOrientationChange(newSize: view.bounds.size)
        }
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }
}
