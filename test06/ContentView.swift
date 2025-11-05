//
//  ContentView.swift
//  test06
//
//  Created by Sabrina Jiang on 9/16/25.
//

import SwiftUI
import Combine

struct SnakeGameView: View {
    @State private var snake: [CGPoint] = [CGPoint(x: 200, y: 400)]
    @State private var food: [CGPoint] = (0..<30).map { _ in
        CGPoint(x: CGFloat.random(in: 40..<360), y: CGFloat.random(in: 80..<760))
    }
    
    @State private var direction: CGVector = .init(dx: 1, dy: 0)
    @State private var gameOver = false
    @State private var isPaused = false
    @State private var gameStarted = false
    
    @State private var score = 0
    @AppStorage("highScore") private var highScore = 0
    
    @State private var fingerPos: CGPoint? = nil
    
    let segmentSpacing: CGFloat = 15
    let snakeRadius: CGFloat = 8
    let moveSpeed: CGFloat = 120.0 // points/sec
    
    // 🕒 Start delay system
    @State private var startTime: Date? = nil
    let collisionDelay: TimeInterval = 2.0
    
    @State private var timer: Publishers.Autoconnect<Timer.TimerPublisher> =
        Timer.publish(every: 1.0/60.0, on: .main, in: .common).autoconnect()
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                Rectangle()
                    .fill(Color.black)
                    .ignoresSafeArea()
                
                // Food particles
                ForEach(0..<food.count, id: \.self) { i in
                    Circle()
                        .fill(Color.red)
                        .frame(width: 10, height: 10)
                        .position(food[i])
                }
                
                // Snake body
                ForEach(0..<snake.count, id: \.self) { i in
                    if i == 0 {
                        // 🐱
                        let offsetHead = CGPoint(
                            x: snake[i].x + direction.dx * snakeRadius * 2,
                            y: snake[i].y + direction.dy * snakeRadius * 2
                        )
                        Image("catmeme")
                            .resizable()
                            .frame(width: snakeRadius*3, height: snakeRadius*3)
                            .position(offsetHead)
                    } else {
                        Circle()
                            .fill(Color.green.opacity(0.7))
                            .frame(width: snakeRadius*2, height: snakeRadius*2)
                            .position(snake[i])
                    }
                }
                
                // Score overlay
                VStack {
                    HStack {
                        Text("Score: \(score)")
                            .foregroundColor(.white)
                        Spacer()
                        Text("High: \(highScore)")
                            .foregroundColor(.white)
                    }
                    .padding([.top, .horizontal])
                    Spacer()
                }
                
                // Start overlay
                if !gameStarted && !gameOver {
                    Text("Touch to Start")
                        .font(.largeTitle)
                        .foregroundColor(.yellow)
                }
                
                // Pause overlay
                if isPaused && !gameOver {
                    VStack {
                        Text("Paused")
                            .font(.largeTitle)
                            .foregroundColor(.yellow)
                        Text("Score: \(score)")
                            .foregroundColor(.white)
                        Text("High Score: \(highScore)")
                            .foregroundColor(.gray)
                    }
                }
                
                // Game Over overlay
                if gameOver {
                    VStack {
                        Text("Game Over")
                            .font(.largeTitle)
                            .foregroundColor(.white)
                        Text("Score: \(score)")
                            .foregroundColor(.white)
                        Text("High Score: \(highScore)")
                            .foregroundColor(.gray)
                        Button("Restart") { restartGame(geo.size) }
                            .padding()
                            .background(Color.white)
                            .cornerRadius(10)
                    }
                }
            }
            // Drag to guide snake
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !gameStarted {
                            gameStarted = true
                            startTime = Date() // 🕒 mark start
                        }
                        fingerPos = value.location
                    }
                    .onEnded { _ in
                        fingerPos = nil
                    }
            )
            // Double tap to pause
            .simultaneousGesture(
                TapGesture(count: 2)
                    .onEnded {
                        if gameStarted && !gameOver { isPaused.toggle() }
                    }
            )
            // Movement loop
            .onReceive(timer) { _ in
                if gameStarted && !gameOver && !isPaused {
                    updateDirection()
                    moveSnake(in: geo.size)
                    checkFood()
                }
            }
        }
    }
    
    // MARK: - Movement
    func updateDirection() {
        guard let finger = fingerPos, let head = snake.first else { return }
        let dx = finger.x - head.x
        let dy = finger.y - head.y
        let len = max(sqrt(dx*dx + dy*dy), 0.001)
        direction = CGVector(dx: dx/len, dy: dy/len)
    }
    
    func moveSnake(in size: CGSize) {
        guard var head = snake.first else { return }
        
        // Move head smoothly
        head.x += direction.dx * moveSpeed * (1.0/60.0)
        head.y += direction.dy * moveSpeed * (1.0/60.0)
        
        // Bounds check
        if head.x < 0 || head.x > size.width || head.y < 0 || head.y > size.height {
            gameOver = true
            return
        }
        
        // Insert new head
        snake.insert(head, at: 0)
        
        // Keep segments spaced
        var newSnake: [CGPoint] = [head]
        for i in 1..<snake.count {
            let prev = newSnake[i-1]
            let seg = snake[i]
            let dx = prev.x - seg.x
            let dy = prev.y - seg.y
            let dist = sqrt(dx*dx + dy*dy)
            if dist > segmentSpacing {
                let newPos = CGPoint(
                    x: seg.x + dx/dist * (dist - segmentSpacing),
                    y: seg.y + dy/dist * (dist - segmentSpacing)
                )
                newSnake.append(newPos)
            } else {
                newSnake.append(seg)
            }
        }
        snake = newSnake
        
        // 🔴 Self-collision check (after grace period)
        if let start = startTime, Date().timeIntervalSince(start) > collisionDelay {
            if snake.count > 5 {
                // 🐱 use the actual cat head offset
                let catHead = CGPoint(
                    x: head.x + direction.dx * snakeRadius * 2.5, // adjust multiplier
                    y: head.y + direction.dy * snakeRadius * 2.5
                )
                
                for i in stride(from: 1, to: snake.count, by: 2) {
                    let dx = catHead.x - snake[i].x
                    let dy = catHead.y - snake[i].y
                    if sqrt(dx*dx + dy*dy) < snakeRadius * 0.7 {
                        gameOver = true
                        return
                    }
                }
            }
        }
    }
    
    // MARK: - Food / Growth
    func checkFood() {
        guard let head = snake.first else { return }
        
        for (i, f) in food.enumerated().reversed() {
            let dx = head.x - f.x
            let dy = head.y - f.y
            if sqrt(dx*dx + dy*dy) < snakeRadius + 6 {
                // Ate food
                food.remove(at: i)
                food.append(CGPoint(
                    x: CGFloat.random(in: 40..<360),
                    y: CGFloat.random(in: 80..<760)
                ))
                
                score += 1
                if score > highScore { highScore = score }
                
                // Add new segment at tail
                if let tail = snake.last {
                    snake.append(tail)
                }
            }
        }
    }
    
    // MARK: - Restart
    func restartGame(_ size: CGSize) {
        snake = [CGPoint(x: size.width/2, y: size.height/2)]
        food = (0..<30).map { _ in
            CGPoint(x: CGFloat.random(in: 40..<size.width-40),
                    y: CGFloat.random(in: 80..<size.height-40))
        }
        direction = .init(dx: 1, dy: 0)
        gameOver = false
        isPaused = false
        gameStarted = false
        score = 0
        startTime = nil
    }
}

struct ContentView: View {
    var body: some View {
        SnakeGameView()
    }
}

#Preview {
    ContentView()
}
