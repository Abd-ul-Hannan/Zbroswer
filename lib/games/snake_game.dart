import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SnakeGame extends StatefulWidget {
  const SnakeGame({super.key});

  @override
  State<SnakeGame> createState() => _SnakeGameState();
}

class _SnakeGameState extends State<SnakeGame> {
  static const int boardSize = 20;
  List<Point<int>> snake = [Point(10, 10)];
  Point<int> food = Point(5, 5);
  Point<int> direction = Point(0, -1);
  Timer? gameTimer;
  int score = 0;
  int highScore = 0;
  bool gameOver = false;
  bool gamePaused = false;
  bool gameStarted = false;

  @override
  void initState() {
    super.initState();
    _loadHighScore();
    generateFood();
  }

  void _loadHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      highScore = prefs.getInt('snake_high_score') ?? 0;
    });
  }

  void _saveHighScore() async {
    if (score > highScore) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('snake_high_score', score);
      setState(() {
        highScore = score;
      });
    }
  }

  void startGame() {
    setState(() {
      gameStarted = true;
      gameOver = false;
      gamePaused = false;
      score = 0;
      snake = [Point(10, 10)];
      direction = Point(0, -1);
    });
    generateFood();
    gameTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      if (!gamePaused) {
        moveSnake();
      }
    });
  }

  void pauseGame() {
    setState(() {
      gamePaused = !gamePaused;
    });
  }

  void moveSnake() {
    if (gameOver || gamePaused) return;

    Point<int> newHead = Point(
      snake.first.x + direction.x,
      snake.first.y + direction.y,
    );

    if (newHead.x < 0 || newHead.x >= boardSize || 
        newHead.y < 0 || newHead.y >= boardSize ||
        snake.contains(newHead)) {
      setState(() => gameOver = true);
      gameTimer?.cancel();
      _saveHighScore();
      return;
    }

    snake.insert(0, newHead);

    if (newHead == food) {
      score++;
      generateFood();
    } else {
      snake.removeLast();
    }

    setState(() {});
  }

  void generateFood() {
    Random random = Random();
    do {
      food = Point(random.nextInt(boardSize), random.nextInt(boardSize));
    } while (snake.contains(food));
  }

  void changeDirection(Point<int> newDirection) {
    if (direction.x + newDirection.x != 0 || direction.y + newDirection.y != 0) {
      direction = newDirection;
    }
  }

  void resetGame() {
    gameTimer?.cancel();
    startGame();
  }

  @override
  void dispose() {
    gameTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Snake Game'),
        backgroundColor: Colors.green,
        actions: [
          if (gameStarted && !gameOver)
            IconButton(
              onPressed: pauseGame,
              icon: Icon(gamePaused ? Icons.play_arrow : Icons.pause),
            ),
          Center(
            child: Text('Score: $score | High: $highScore', 
                      style: const TextStyle(fontSize: 14)),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent && gameStarted && !gameOver && !gamePaused) {
            switch (event.logicalKey) {
              case LogicalKeyboardKey.arrowUp:
                changeDirection(Point(0, -1));
                return KeyEventResult.handled;
              case LogicalKeyboardKey.arrowDown:
                changeDirection(Point(0, 1));
                return KeyEventResult.handled;
              case LogicalKeyboardKey.arrowLeft:
                changeDirection(Point(-1, 0));
                return KeyEventResult.handled;
              case LogicalKeyboardKey.arrowRight:
                changeDirection(Point(1, 0));
                return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: GestureDetector(
                    onPanUpdate: (details) {
                      if (gameStarted && !gameOver && !gamePaused) {
                        double dx = details.delta.dx;
                        double dy = details.delta.dy;
                        
                        if (dx.abs() > dy.abs()) {
                          changeDirection(dx > 0 ? Point(1, 0) : Point(-1, 0));
                        } else {
                          changeDirection(dy > 0 ? Point(0, 1) : Point(0, -1));
                        }
                      }
                    },
                    child: Container(
                      margin: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white, width: 2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: boardSize,
                        ),
                        itemCount: boardSize * boardSize,
                        itemBuilder: (context, index) {
                          int x = index % boardSize;
                          int y = index ~/ boardSize;
                          Point<int> currentPoint = Point(x, y);

                          Color cellColor = Colors.black;
                          if (snake.contains(currentPoint)) {
                            cellColor = snake.first == currentPoint ? Colors.green : Colors.lightGreen;
                          } else if (currentPoint == food) {
                            cellColor = Colors.red;
                          }

                          return Container(
                            margin: const EdgeInsets.all(0.5),
                            decoration: BoxDecoration(
                              color: cellColor,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                if (gameStarted && (gameOver || gamePaused))
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text(
                          gamePaused ? 'Game Paused' : 'Game Over!',
                          style: TextStyle(
                            color: gamePaused ? Colors.yellow : Colors.red, 
                            fontSize: 24, 
                            fontWeight: FontWeight.bold
                          ),
                        ),
                        if (gameOver) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Final Score: $score',
                            style: const TextStyle(color: Colors.white, fontSize: 18),
                          ),
                          if (score == highScore)
                            const Text(
                              'New High Score!',
                              style: TextStyle(color: Colors.yellow, fontSize: 16),
                            ),
                        ],
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: gamePaused ? pauseGame : resetGame,
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                          child: Text(
                            gamePaused ? 'Resume' : 'Play Again',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Column(
                        children: [
                          IconButton(
                            onPressed: gameStarted && !gameOver && !gamePaused 
                                ? () => changeDirection(Point(0, -1)) : null,
                            icon: const Icon(Icons.keyboard_arrow_up, color: Colors.white, size: 40),
                          ),
                          Row(
                            children: [
                              IconButton(
                                onPressed: gameStarted && !gameOver && !gamePaused 
                                    ? () => changeDirection(Point(-1, 0)) : null,
                                icon: const Icon(Icons.keyboard_arrow_left, color: Colors.white, size: 40),
                              ),
                              const SizedBox(width: 40),
                              IconButton(
                                onPressed: gameStarted && !gameOver && !gamePaused 
                                    ? () => changeDirection(Point(1, 0)) : null,
                                icon: const Icon(Icons.keyboard_arrow_right, color: Colors.white, size: 40),
                              ),
                            ],
                          ),
                          IconButton(
                            onPressed: gameStarted && !gameOver && !gamePaused 
                                ? () => changeDirection(Point(0, 1)) : null,
                            icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 40),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            // Game start overlay
            if (!gameStarted)
              Container(
                color: Colors.black54,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Snake Game',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Use arrow keys or swipe to control the snake',
                        style: TextStyle(fontSize: 16, color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton(
                        onPressed: startGame,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        ),
                        child: const Text(
                          'Start Game',
                          style: TextStyle(fontSize: 18, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}