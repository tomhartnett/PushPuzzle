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

    override var prefersStatusBarHidden: Bool {
        return true
    }
}
