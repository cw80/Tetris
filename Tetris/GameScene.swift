import SpriteKit

// MARK: - Tetromino Definitions

enum TetrominoType: Int, CaseIterable {
    case I, O, T, S, Z, J, L

    var color: SKColor {
        switch self {
        case .I: return SKColor.cyan
        case .O: return SKColor.yellow
        case .T: return SKColor.purple
        case .S: return SKColor.green
        case .Z: return SKColor.red
        case .J: return SKColor.blue
        case .L: return SKColor.orange
        }
    }

    /// Each rotation state is an array of (row, col) offsets from the piece origin.
    var rotations: [[(Int, Int)]] {
        switch self {
        case .I: return [
            [(0,0),(0,1),(0,2),(0,3)],
            [(0,0),(1,0),(2,0),(3,0)],
            [(0,0),(0,1),(0,2),(0,3)],
            [(0,0),(1,0),(2,0),(3,0)]
        ]
        case .O: return [
            [(0,0),(0,1),(1,0),(1,1)],
            [(0,0),(0,1),(1,0),(1,1)],
            [(0,0),(0,1),(1,0),(1,1)],
            [(0,0),(0,1),(1,0),(1,1)]
        ]
        case .T: return [
            [(0,0),(0,1),(0,2),(1,1)],
            [(0,0),(1,0),(2,0),(1,1)],
            [(0,1),(1,0),(1,1),(1,2)],
            [(0,0),(1,0),(2,0),(1,-1)]
        ]
        case .S: return [
            [(0,1),(0,2),(1,0),(1,1)],
            [(0,0),(1,0),(1,1),(2,1)],
            [(0,1),(0,2),(1,0),(1,1)],
            [(0,0),(1,0),(1,1),(2,1)]
        ]
        case .Z: return [
            [(0,0),(0,1),(1,1),(1,2)],
            [(0,1),(1,0),(1,1),(2,0)],
            [(0,0),(0,1),(1,1),(1,2)],
            [(0,1),(1,0),(1,1),(2,0)]
        ]
        case .J: return [
            [(0,0),(1,0),(1,1),(1,2)],
            [(0,0),(0,1),(1,0),(2,0)],
            [(0,0),(0,1),(0,2),(1,2)],
            [(0,0),(1,0),(2,0),(2,-1)]
        ]
        case .L: return [
            [(0,2),(1,0),(1,1),(1,2)],
            [(0,0),(1,0),(2,0),(2,1)],
            [(0,0),(0,1),(0,2),(1,0)],
            [(0,0),(0,1),(1,1),(2,1)]
        ]
        }
    }
}

struct Tetromino {
    var type: TetrominoType
    var rotation: Int = 0
    var row: Int
    var col: Int

    var blocks: [(Int, Int)] {
        return type.rotations[rotation]
    }

    /// Absolute board positions for each block.
    var absolutePositions: [(Int, Int)] {
        return blocks.map { (row + $0.0, col + $0.1) }
    }

    mutating func rotateClockwise() {
        rotation = (rotation + 1) % 4
    }

    mutating func rotateCounterClockwise() {
        rotation = (rotation + 3) % 4
    }
}

// MARK: - Game State

enum GameState {
    case start
    case playing
    case paused
    case gameOver
}

// MARK: - GameScene

class GameScene: SKScene {

    // Board dimensions
    let numRows = 20
    let numCols = 10

    // Cell size computed from scene
    var cellSize: CGFloat = 0

    // Board origin (bottom-left of the play field)
    var boardOrigin: CGPoint = .zero

    // The board grid: nil means empty, otherwise stores a color.
    var board: [[SKColor?]] = []

    // Nodes for locked blocks
    var blockNodes: [[SKShapeNode?]] = []

    // Current and next piece
    var currentPiece: Tetromino!
    var nextPiece: Tetromino!

    // Nodes for the active piece
    var activeNodes: [SKShapeNode] = []

    // Next piece preview nodes
    var nextPieceNodes: [SKShapeNode] = []

    // Timing
    var lastDropTime: TimeInterval = 0
    var dropInterval: TimeInterval = 0.8

    // Score
    var score: Int = 0
    var level: Int = 1
    var linesCleared: Int = 0

    // Labels
    var scoreLabel: SKLabelNode!
    var levelLabel: SKLabelNode!
    var nextLabel: SKLabelNode!

    // Game state
    var gameState: GameState = .start

    // Touch tracking
    var touchStartPoint: CGPoint?
    var touchStartTime: TimeInterval?
    var lastHorizontalStep: CGFloat = 0

    // Border node
    var borderNode: SKShapeNode!

    // UI layer nodes
    var startScreenNode: SKNode?
    var pauseOverlayNode: SKNode?
    var gameOverOverlayNode: SKNode?
    var pauseButton: SKNode?
    var endGameButton: SKNode?

    // MARK: - Scene Setup

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.1, green: 0.1, blue: 0.15, alpha: 1.0)
        showStartScreen()
    }

    func setupBoard() {
        // Calculate cell size to fit the board within the scene width with padding.
        let horizontalPadding: CGFloat = 40
        let availableWidth = size.width - horizontalPadding
        let availableHeight = size.height * 0.65
        cellSize = min(availableWidth / CGFloat(numCols), availableHeight / CGFloat(numRows))

        let boardWidth = cellSize * CGFloat(numCols)
        let boardHeight = cellSize * CGFloat(numRows)
        boardOrigin = CGPoint(
            x: (size.width - boardWidth) / 2,
            y: (size.height - boardHeight) / 2 - 60
        )

        // Initialize empty board
        board = Array(repeating: Array(repeating: nil, count: numCols), count: numRows)
        blockNodes = Array(repeating: Array(repeating: nil, count: numCols), count: numRows)

        // Draw border
        let borderRect = CGRect(
            x: boardOrigin.x - 2,
            y: boardOrigin.y - 2,
            width: boardWidth + 4,
            height: boardHeight + 4
        )
        borderNode = SKShapeNode(rect: borderRect)
        borderNode.strokeColor = SKColor.white
        borderNode.lineWidth = 2
        borderNode.fillColor = SKColor(red: 0.05, green: 0.05, blue: 0.1, alpha: 1.0)
        borderNode.zPosition = -1
        addChild(borderNode)

        // Draw grid lines
        let gridNode = SKNode()
        for r in 1..<numRows {
            let y = boardOrigin.y + CGFloat(r) * cellSize
            let path = CGMutablePath()
            path.move(to: CGPoint(x: boardOrigin.x, y: y))
            path.addLine(to: CGPoint(x: boardOrigin.x + boardWidth, y: y))
            let line = SKShapeNode(path: path)
            line.strokeColor = SKColor(white: 0.2, alpha: 1.0)
            line.lineWidth = 0.5
            gridNode.addChild(line)
        }
        for c in 1..<numCols {
            let x = boardOrigin.x + CGFloat(c) * cellSize
            let path = CGMutablePath()
            path.move(to: CGPoint(x: x, y: boardOrigin.y))
            path.addLine(to: CGPoint(x: x, y: boardOrigin.y + boardHeight))
            let line = SKShapeNode(path: path)
            line.strokeColor = SKColor(white: 0.2, alpha: 1.0)
            line.lineWidth = 0.5
            gridNode.addChild(line)
        }
        gridNode.zPosition = -0.5
        addChild(gridNode)
    }

    func setupLabels() {
        let boardTop = boardOrigin.y + cellSize * CGFloat(numRows)
        let boardWidth = cellSize * CGFloat(numCols)
        let labelY = boardTop + 12

        scoreLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
        scoreLabel.fontSize = 18
        scoreLabel.fontColor = .white
        scoreLabel.horizontalAlignmentMode = .left
        scoreLabel.position = CGPoint(x: boardOrigin.x, y: labelY)
        scoreLabel.text = "Score: 0"
        addChild(scoreLabel)

        levelLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
        levelLabel.fontSize = 18
        levelLabel.fontColor = .white
        levelLabel.horizontalAlignmentMode = .right
        let boardRight = boardOrigin.x + boardWidth
        levelLabel.position = CGPoint(x: boardRight, y: labelY)
        levelLabel.text = "Level: 1"
        addChild(levelLabel)

        // Next piece label below the board
        nextLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
        nextLabel.fontSize = 14
        nextLabel.fontColor = .white
        nextLabel.horizontalAlignmentMode = .left
        nextLabel.position = CGPoint(x: boardOrigin.x, y: boardOrigin.y - 24)
        nextLabel.text = "Next:"
        addChild(nextLabel)
    }

    func setupButtons() {
        let boardTop = boardOrigin.y + cellSize * CGFloat(numRows)
        let buttonY = boardTop + 44

        // Pause button
        pauseButton = makeButton(text: "Pause", name: "pauseButton",
                                 position: CGPoint(x: boardOrigin.x + 40, y: buttonY))
        addChild(pauseButton!)

        // End Game button
        let boardRight = boardOrigin.x + cellSize * CGFloat(numCols)
        endGameButton = makeButton(text: "End", name: "endGameButton",
                                   position: CGPoint(x: boardRight - 40, y: buttonY))
        addChild(endGameButton!)
    }

    func makeButton(text: String, name: String, position: CGPoint) -> SKNode {
        let container = SKNode()
        container.name = name
        container.position = position

        let bg = SKShapeNode(rectOf: CGSize(width: 70, height: 30), cornerRadius: 6)
        bg.fillColor = SKColor(white: 0.25, alpha: 1.0)
        bg.strokeColor = SKColor(white: 0.5, alpha: 1.0)
        bg.lineWidth = 1
        bg.name = name
        container.addChild(bg)

        let label = SKLabelNode(fontNamed: "Helvetica-Bold")
        label.fontSize = 14
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.text = text
        label.name = name
        container.addChild(label)

        container.zPosition = 5
        return container
    }

    // MARK: - Start Screen

    func showStartScreen() {
        gameState = .start
        let node = SKNode()
        node.zPosition = 20

        // Title
        let title = SKLabelNode(fontNamed: "Helvetica-Bold")
        title.fontSize = 48
        title.fontColor = .cyan
        title.position = CGPoint(x: size.width / 2, y: size.height / 2 + 80)
        title.text = "Craig's TETRIS"
        node.addChild(title)

        // Decorative blocks around the title
        let blockColors: [SKColor] = [.cyan, .yellow, .purple, .green, .red, .blue, .orange]
        for i in 0..<7 {
            let block = SKShapeNode(rectOf: CGSize(width: 20, height: 20), cornerRadius: 3)
            block.fillColor = blockColors[i]
            block.strokeColor = blockColors[i].withAlphaComponent(0.7)
            let angle = CGFloat(i) * (.pi * 2 / 7)
            block.position = CGPoint(
                x: size.width / 2 + cos(angle) * 110,
                y: size.height / 2 + 80 + sin(angle) * 50
            )
            let rotate = SKAction.rotate(byAngle: .pi * 2, duration: 4)
            block.run(SKAction.repeatForever(rotate))
            node.addChild(block)
        }

        // Play button
        let playContainer = SKNode()
        playContainer.name = "playButton"
        playContainer.position = CGPoint(x: size.width / 2, y: size.height / 2 - 20)

        let playBg = SKShapeNode(rectOf: CGSize(width: 160, height: 50), cornerRadius: 10)
        playBg.fillColor = SKColor(red: 0.1, green: 0.6, blue: 0.3, alpha: 1.0)
        playBg.strokeColor = SKColor(red: 0.2, green: 0.8, blue: 0.4, alpha: 1.0)
        playBg.lineWidth = 2
        playBg.name = "playButton"
        playContainer.addChild(playBg)

        let playLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
        playLabel.fontSize = 24
        playLabel.fontColor = .white
        playLabel.verticalAlignmentMode = .center
        playLabel.text = "PLAY"
        playLabel.name = "playButton"
        playContainer.addChild(playLabel)

        // Pulse animation
        let scaleUp = SKAction.scale(to: 1.05, duration: 0.8)
        let scaleDown = SKAction.scale(to: 0.95, duration: 0.8)
        scaleUp.timingMode = .easeInEaseOut
        scaleDown.timingMode = .easeInEaseOut
        playContainer.run(SKAction.repeatForever(SKAction.sequence([scaleUp, scaleDown])))

        node.addChild(playContainer)

        // Controls hint
        let hint = SKLabelNode(fontNamed: "Helvetica")
        hint.fontSize = 13
        hint.fontColor = SKColor.lightGray
        hint.position = CGPoint(x: size.width / 2, y: size.height / 2 - 80)
        hint.text = "Tap: Rotate  |  Drag: Move  |  Swipe Down: Drop"
        node.addChild(hint)

        addChild(node)
        startScreenNode = node
    }

    // MARK: - Pause Overlay

    func showPauseOverlay() {
        gameState = .paused

        let node = SKNode()
        node.zPosition = 20

        // Dim background
        let dimBg = SKShapeNode(rectOf: CGSize(width: size.width, height: size.height))
        dimBg.fillColor = SKColor(white: 0, alpha: 0.6)
        dimBg.strokeColor = .clear
        dimBg.position = CGPoint(x: size.width / 2, y: size.height / 2)
        dimBg.name = "pauseOverlay"
        node.addChild(dimBg)

        // Paused label
        let label = SKLabelNode(fontNamed: "Helvetica-Bold")
        label.fontSize = 40
        label.fontColor = .white
        label.position = CGPoint(x: size.width / 2, y: size.height / 2 + 40)
        label.text = "PAUSED"
        node.addChild(label)

        // Resume button
        let resumeContainer = SKNode()
        resumeContainer.name = "resumeButton"
        resumeContainer.position = CGPoint(x: size.width / 2, y: size.height / 2 - 30)

        let resumeBg = SKShapeNode(rectOf: CGSize(width: 140, height: 44), cornerRadius: 8)
        resumeBg.fillColor = SKColor(red: 0.1, green: 0.6, blue: 0.3, alpha: 1.0)
        resumeBg.strokeColor = SKColor(red: 0.2, green: 0.8, blue: 0.4, alpha: 1.0)
        resumeBg.lineWidth = 2
        resumeBg.name = "resumeButton"
        resumeContainer.addChild(resumeBg)

        let resumeLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
        resumeLabel.fontSize = 20
        resumeLabel.fontColor = .white
        resumeLabel.verticalAlignmentMode = .center
        resumeLabel.text = "RESUME"
        resumeLabel.name = "resumeButton"
        resumeContainer.addChild(resumeLabel)

        node.addChild(resumeContainer)

        addChild(node)
        pauseOverlayNode = node
    }

    func hidePauseOverlay() {
        pauseOverlayNode?.removeFromParent()
        pauseOverlayNode = nil
        gameState = .playing
        lastDropTime = 0 // Reset so the piece doesn't jump after unpause
    }

    // MARK: - Game Over Overlay

    func showGameOverOverlay() {
        gameState = .gameOver
        activeNodes.forEach { $0.removeFromParent() }
        activeNodes.removeAll()

        let node = SKNode()
        node.zPosition = 20

        // Dim background
        let dimBg = SKShapeNode(rectOf: CGSize(width: size.width, height: size.height))
        dimBg.fillColor = SKColor(white: 0, alpha: 0.6)
        dimBg.strokeColor = .clear
        dimBg.position = CGPoint(x: size.width / 2, y: size.height / 2)
        node.addChild(dimBg)

        // Game Over label
        let label = SKLabelNode(fontNamed: "Helvetica-Bold")
        label.fontSize = 36
        label.fontColor = .white
        label.position = CGPoint(x: size.width / 2, y: size.height / 2 + 60)
        label.text = "GAME OVER"
        node.addChild(label)

        // Final score
        let scoreLine = SKLabelNode(fontNamed: "Helvetica")
        scoreLine.fontSize = 22
        scoreLine.fontColor = SKColor.lightGray
        scoreLine.position = CGPoint(x: size.width / 2, y: size.height / 2 + 20)
        scoreLine.text = "Score: \(score)  |  Level: \(level)"
        node.addChild(scoreLine)

        // Play Again button
        let playAgainContainer = SKNode()
        playAgainContainer.name = "playAgainButton"
        playAgainContainer.position = CGPoint(x: size.width / 2, y: size.height / 2 - 40)

        let playAgainBg = SKShapeNode(rectOf: CGSize(width: 160, height: 44), cornerRadius: 8)
        playAgainBg.fillColor = SKColor(red: 0.1, green: 0.6, blue: 0.3, alpha: 1.0)
        playAgainBg.strokeColor = SKColor(red: 0.2, green: 0.8, blue: 0.4, alpha: 1.0)
        playAgainBg.lineWidth = 2
        playAgainBg.name = "playAgainButton"
        playAgainContainer.addChild(playAgainBg)

        let playAgainLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
        playAgainLabel.fontSize = 20
        playAgainLabel.fontColor = .white
        playAgainLabel.verticalAlignmentMode = .center
        playAgainLabel.text = "PLAY AGAIN"
        playAgainLabel.name = "playAgainButton"
        playAgainContainer.addChild(playAgainLabel)

        node.addChild(playAgainContainer)

        addChild(node)
        gameOverOverlayNode = node
    }

    // MARK: - Game Lifecycle

    func startGame() {
        startScreenNode?.removeFromParent()
        startScreenNode = nil

        setupBoard()
        setupLabels()
        setupButtons()
        gameState = .playing
        spawnNewPiece()
    }

    func endGame() {
        // Triggered by End button — go straight to game over
        showGameOverOverlay()
    }

    func restartGame() {
        gameOverOverlayNode?.removeFromParent()
        gameOverOverlayNode = nil

        removeAllChildren()

        board = []
        blockNodes = []
        activeNodes = []
        nextPieceNodes = []
        currentPiece = nil
        nextPiece = nil
        score = 0
        level = 1
        linesCleared = 0
        dropInterval = 0.8
        lastDropTime = 0
        pauseButton = nil
        endGameButton = nil

        setupBoard()
        setupLabels()
        setupButtons()
        gameState = .playing
        spawnNewPiece()
    }

    // MARK: - Piece Management

    func randomPiece() -> Tetromino {
        let type = TetrominoType.allCases.randomElement()!
        return Tetromino(type: type, rotation: 0, row: numRows - 1, col: numCols / 2 - 1)
    }

    func spawnNewPiece() {
        if currentPiece == nil {
            // First spawn — create both current and next
            currentPiece = randomPiece()
            nextPiece = randomPiece()
        } else {
            currentPiece = nextPiece
            currentPiece.row = numRows - 1
            currentPiece.col = numCols / 2 - 1
            nextPiece = randomPiece()
        }

        // Check if spawn position is valid; if not, game over.
        if !isValidPosition(currentPiece) {
            // Try one row higher
            currentPiece.row = numRows
            if !isValidPosition(currentPiece) {
                showGameOverOverlay()
                return
            }
        }

        drawActivePiece()
        drawNextPiecePreview()
    }

    func isValidPosition(_ piece: Tetromino) -> Bool {
        for (r, c) in piece.absolutePositions {
            if c < 0 || c >= numCols { return false }
            if r < 0 { return false }
            // Allow pieces above the board (spawning)
            if r < numRows {
                if board[r][c] != nil { return false }
            }
        }
        return true
    }

    // MARK: - Drawing

    func positionForCell(row: Int, col: Int) -> CGPoint {
        return CGPoint(
            x: boardOrigin.x + CGFloat(col) * cellSize + cellSize / 2,
            y: boardOrigin.y + CGFloat(row) * cellSize + cellSize / 2
        )
    }

    func makeBlockNode(color: SKColor) -> SKShapeNode {
        let inset: CGFloat = 1.5
        let blockRect = CGRect(x: -cellSize / 2 + inset, y: -cellSize / 2 + inset,
                               width: cellSize - inset * 2, height: cellSize - inset * 2)
        let node = SKShapeNode(rect: blockRect, cornerRadius: 2)
        node.fillColor = color
        node.strokeColor = color.withAlphaComponent(0.7)
        node.lineWidth = 1
        return node
    }

    func drawActivePiece() {
        // Remove old active nodes
        activeNodes.forEach { $0.removeFromParent() }
        activeNodes.removeAll()

        guard let piece = currentPiece else { return }

        for (r, c) in piece.absolutePositions {
            guard r >= 0 && r < numRows && c >= 0 && c < numCols else { continue }
            let node = makeBlockNode(color: piece.type.color)
            node.position = positionForCell(row: r, col: c)
            node.zPosition = 1
            addChild(node)
            activeNodes.append(node)
        }
    }

    func drawNextPiecePreview() {
        nextPieceNodes.forEach { $0.removeFromParent() }
        nextPieceNodes.removeAll()

        guard let piece = nextPiece else { return }

        let previewCellSize = cellSize * 0.6
        let baseX = nextLabel.position.x + 50
        let baseY = nextLabel.position.y + 2

        for (r, c) in piece.type.rotations[0] {
            let node = SKShapeNode(
                rect: CGRect(x: 0, y: 0, width: previewCellSize - 2, height: previewCellSize - 2),
                cornerRadius: 2
            )
            node.fillColor = piece.type.color
            node.strokeColor = piece.type.color.withAlphaComponent(0.7)
            node.lineWidth = 1
            node.position = CGPoint(
                x: baseX + CGFloat(c) * previewCellSize,
                y: baseY - CGFloat(r) * previewCellSize
            )
            node.zPosition = 1
            addChild(node)
            nextPieceNodes.append(node)
        }
    }

    func lockPiece() {
        guard let piece = currentPiece else { return }

        for (r, c) in piece.absolutePositions {
            guard r >= 0 && r < numRows && c >= 0 && c < numCols else {
                // Block above the board means game over
                showGameOverOverlay()
                return
            }
            board[r][c] = piece.type.color
            let node = makeBlockNode(color: piece.type.color)
            node.position = positionForCell(row: r, col: c)
            node.zPosition = 0.5
            addChild(node)
            blockNodes[r][c] = node
        }

        // Remove active piece visuals
        activeNodes.forEach { $0.removeFromParent() }
        activeNodes.removeAll()

        clearFullLines()
        spawnNewPiece()
    }

    // MARK: - Line Clearing

    func clearFullLines() {
        var linesToClear: [Int] = []

        for r in 0..<numRows {
            if board[r].allSatisfy({ $0 != nil }) {
                linesToClear.append(r)
            }
        }

        guard !linesToClear.isEmpty else { return }

        // Remove the lines (process top-to-bottom so indices stay valid after removal)
        for r in linesToClear.reversed() {
            // Remove node sprites
            for c in 0..<numCols {
                blockNodes[r][c]?.removeFromParent()
            }
            board.remove(at: r)
            blockNodes.remove(at: r)
        }

        // Add new empty rows at the top
        for _ in 0..<linesToClear.count {
            board.append(Array(repeating: nil, count: numCols))
            blockNodes.append(Array(repeating: nil, count: numCols))
        }

        // Reposition all remaining block nodes
        for r in 0..<numRows {
            for c in 0..<numCols {
                blockNodes[r][c]?.position = positionForCell(row: r, col: c)
            }
        }

        // Update score
        let lines = linesToClear.count
        let points: Int
        switch lines {
        case 1: points = 100 * level
        case 2: points = 300 * level
        case 3: points = 500 * level
        case 4: points = 800 * level
        default: points = 0
        }
        score += points
        linesCleared += lines
        level = linesCleared / 10 + 1
        dropInterval = max(0.1, 0.8 - Double(level - 1) * 0.07)

        scoreLabel.text = "Score: \(score)"
        levelLabel.text = "Level: \(level)"
    }

    // MARK: - Movement

    func movePiece(rowDelta: Int, colDelta: Int) -> Bool {
        guard var piece = currentPiece else { return false }
        piece.row += rowDelta
        piece.col += colDelta
        if isValidPosition(piece) {
            currentPiece = piece
            drawActivePiece()
            return true
        }
        return false
    }

    func rotatePiece() {
        guard var piece = currentPiece else { return }
        piece.rotateClockwise()

        // Try basic rotation
        if isValidPosition(piece) {
            currentPiece = piece
            drawActivePiece()
            return
        }

        // Wall kicks: try shifting left, right, up
        for offset in [(0, -1), (0, 1), (0, -2), (0, 2), (1, 0)] {
            var kicked = piece
            kicked.row += offset.0
            kicked.col += offset.1
            if isValidPosition(kicked) {
                currentPiece = kicked
                drawActivePiece()
                return
            }
        }
        // Rotation failed — do nothing
    }

    func hardDrop() {
        guard currentPiece != nil else { return }
        while movePiece(rowDelta: -1, colDelta: 0) { }
        lockPiece()
    }

    // MARK: - Touch Handling

    /// Check if a touch hit a named node.
    func nodeName(at point: CGPoint) -> String? {
        let hitNodes = nodes(at: point)
        for node in hitNodes {
            if let name = node.name {
                return name
            }
        }
        return nil
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let tappedName = nodeName(at: location)

        switch gameState {
        case .start:
            if tappedName == "playButton" {
                startGame()
            }

        case .playing:
            if tappedName == "pauseButton" {
                showPauseOverlay()
                return
            }
            if tappedName == "endGameButton" {
                endGame()
                return
            }
            touchStartPoint = location
            touchStartTime = touch.timestamp
            lastHorizontalStep = 0

        case .paused:
            if tappedName == "resumeButton" {
                hidePauseOverlay()
            }

        case .gameOver:
            if tappedName == "playAgainButton" {
                restartGame()
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard gameState == .playing else { return }
        guard let touch = touches.first, let startPoint = touchStartPoint else { return }

        let currentPoint = touch.location(in: self)
        let dx = currentPoint.x - startPoint.x
        let dy = currentPoint.y - startPoint.y

        // Horizontal movement — step every cellSize distance
        let horizontalThreshold = cellSize
        let steps = floor(dx / horizontalThreshold)
        let stepDelta = Int(steps - lastHorizontalStep)
        if stepDelta != 0 {
            let direction = stepDelta > 0 ? 1 : -1
            for _ in 0..<abs(stepDelta) {
                _ = movePiece(rowDelta: 0, colDelta: direction)
            }
            lastHorizontalStep = steps
        }

        // Soft drop on swipe down
        if dy < -cellSize * 1.5 {
            _ = movePiece(rowDelta: -1, colDelta: 0)
            touchStartPoint = currentPoint
            lastHorizontalStep = 0
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard gameState == .playing else { return }
        guard let touch = touches.first, let startPoint = touchStartPoint else { return }

        let endPoint = touch.location(in: self)
        let dx = endPoint.x - startPoint.x
        let dy = endPoint.y - startPoint.y
        let elapsed = touch.timestamp - (touchStartTime ?? touch.timestamp)

        // Quick tap — rotate (only if not on a button)
        if abs(dx) < 20 && abs(dy) < 20 && elapsed < 0.3 {
            let tappedName = nodeName(at: endPoint)
            if tappedName != "pauseButton" && tappedName != "endGameButton" {
                rotatePiece()
            }
        }
        // Fast swipe down — hard drop
        else if dy < -80 && elapsed < 0.3 {
            hardDrop()
        }

        touchStartPoint = nil
        touchStartTime = nil
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchStartPoint = nil
        touchStartTime = nil
    }

    // MARK: - Game Loop

    override func update(_ currentTime: TimeInterval) {
        guard gameState == .playing else { return }

        if lastDropTime == 0 {
            lastDropTime = currentTime
            return
        }

        if currentTime - lastDropTime >= dropInterval {
            lastDropTime = currentTime
            if !movePiece(rowDelta: -1, colDelta: 0) {
                lockPiece()
            }
        }
    }
}
