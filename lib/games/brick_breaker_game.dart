import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BrickBreakerGame extends StatefulWidget {
  const BrickBreakerGame({super.key});

  @override
  State<BrickBreakerGame> createState() => _BrickBreakerGameState();
}

class _BrickBreakerGameState extends State<BrickBreakerGame>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  Timer? _gameTimer;
  
  // Game state
  bool _gameStarted = false;
  bool _gameOver = false;
  bool _gamePaused = false;
  int _score = 0;
  int _highScore = 0;
  int _lives = 3;
  
  // Game objects
  Offset _ballPosition = const Offset(200, 400);
  Offset _ballVelocity = const Offset(3, -3);
  double _paddleX = 150;
  final double _paddleWidth = 100;
  final double _paddleHeight = 15;
  final double _ballRadius = 8;
  
  // Bricks
  List<Brick> _bricks = [];
  final int _brickRows = 6;
  final int _brickCols = 8;
  final double _brickWidth = 45;
  final double _brickHeight = 20;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 16),
      vsync: this,
    );
    _loadHighScore();
    _initializeBricks();
  }

  void _loadHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _highScore = prefs.getInt('brick_breaker_high_score') ?? 0;
    });
  }

  void _saveHighScore() async {
    if (_score > _highScore) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('brick_breaker_high_score', _score);
      setState(() {
        _highScore = _score;
      });
    }
  }

  void _initializeBricks() {
    _bricks.clear();
    final colors = [Colors.red, Colors.orange, Colors.yellow, Colors.green, Colors.blue, Colors.purple];
    
    for (int row = 0; row < _brickRows; row++) {
      for (int col = 0; col < _brickCols; col++) {
        _bricks.add(Brick(
          x: col * (_brickWidth + 2) + 20,
          y: row * (_brickHeight + 2) + 80,
          width: _brickWidth,
          height: _brickHeight,
          color: colors[row % colors.length],
          points: (_brickRows - row) * 10,
        ));
      }
    }
  }

  void _startGame() {
    setState(() {
      _gameStarted = true;
      _gameOver = false;
      _gamePaused = false;
      _score = 0;
      _lives = 3;
      _ballPosition = const Offset(200, 400);
      _ballVelocity = const Offset(3, -3);
      _paddleX = 150;
    });
    _initializeBricks();
    _startGameLoop();
  }

  void _startGameLoop() {
    _gameTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (!_gamePaused && !_gameOver) {
        _updateGame();
      }
    });
  }

  void _updateGame() {
    setState(() {
      // Update ball position
      _ballPosition = Offset(
        _ballPosition.dx + _ballVelocity.dx,
        _ballPosition.dy + _ballVelocity.dy,
      );

      // Wall collisions
      if (_ballPosition.dx <= _ballRadius || _ballPosition.dx >= 400 - _ballRadius) {
        _ballVelocity = Offset(-_ballVelocity.dx, _ballVelocity.dy);
      }
      if (_ballPosition.dy <= _ballRadius) {
        _ballVelocity = Offset(_ballVelocity.dx, -_ballVelocity.dy);
      }

      // Paddle collision
      if (_ballPosition.dy >= 500 - _paddleHeight - _ballRadius &&
          _ballPosition.dx >= _paddleX &&
          _ballPosition.dx <= _paddleX + _paddleWidth) {
        double hitPos = (_ballPosition.dx - _paddleX) / _paddleWidth;
        double angle = (hitPos - 0.5) * pi / 3;
        double speed = sqrt(_ballVelocity.dx * _ballVelocity.dx + _ballVelocity.dy * _ballVelocity.dy);
        _ballVelocity = Offset(sin(angle) * speed, -cos(angle) * speed);
      }

      // Brick collisions
      for (int i = _bricks.length - 1; i >= 0; i--) {
        if (_bricks[i].checkCollision(_ballPosition, _ballRadius)) {
          _bricks.removeAt(i);
          _ballVelocity = Offset(_ballVelocity.dx, -_ballVelocity.dy);
          _score += _bricks.length > i ? _bricks[i].points : 10;
          break;
        }
      }

      // Check win condition
      if (_bricks.isEmpty) {
        _gameOver = true;
        _gameTimer?.cancel();
        _saveHighScore();
      }

      // Check lose condition
      if (_ballPosition.dy > 600) {
        _lives--;
        if (_lives <= 0) {
          _gameOver = true;
          _gameTimer?.cancel();
          _saveHighScore();
        } else {
          _ballPosition = const Offset(200, 400);
          _ballVelocity = const Offset(3, -3);
        }
      }
    });
  }

  void _pauseGame() {
    setState(() {
      _gamePaused = !_gamePaused;
    });
  }

  void _movePaddle(double delta) {
    setState(() {
      _paddleX = (_paddleX + delta).clamp(0, 400 - _paddleWidth);
    });
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Brick Breaker'),
        backgroundColor: Colors.orange,
        actions: [
          if (_gameStarted && !_gameOver)
            IconButton(
              onPressed: _pauseGame,
              icon: Icon(_gamePaused ? Icons.play_arrow : Icons.pause),
            ),
          Center(
            child: Text('Score: $_score | High: $_highScore', 
                      style: const TextStyle(fontSize: 14)),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent && _gameStarted && !_gameOver && !_gamePaused) {
            switch (event.logicalKey) {
              case LogicalKeyboardKey.arrowLeft:
                _movePaddle(-15);
                return KeyEventResult.handled;
              case LogicalKeyboardKey.arrowRight:
                _movePaddle(15);
                return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          onPanUpdate: (details) {
            if (_gameStarted && !_gameOver && !_gamePaused) {
              _movePaddle(details.delta.dx);
            }
          },
          child: Container(
            width: double.infinity,
            height: double.infinity,
            child: Stack(
              children: [
                // Game area
                Container(
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: CustomPaint(
                    size: const Size(400, 600),
                    painter: GamePainter(
                      ballPosition: _ballPosition,
                      ballRadius: _ballRadius,
                      paddleX: _paddleX,
                      paddleWidth: _paddleWidth,
                      paddleHeight: _paddleHeight,
                      bricks: _bricks,
                    ),
                  ),
                ),
                
                // Game status overlay
                if (!_gameStarted || _gameOver || _gamePaused)
                  Container(
                    color: Colors.black54,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (!_gameStarted)
                            ...[
                              const Text(
                                'Brick Breaker',
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Use arrow keys or swipe to move paddle',
                                style: TextStyle(fontSize: 16, color: Colors.white70),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 32),
                              ElevatedButton(
                                onPressed: _startGame,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                                ),
                                child: const Text(
                                  'Start Game',
                                  style: TextStyle(fontSize: 18, color: Colors.white),
                                ),
                              ),
                            ]
                          else if (_gamePaused)
                            ...[
                              const Text(
                                'Game Paused',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _pauseGame,
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                child: const Text('Resume', style: TextStyle(color: Colors.white)),
                              ),
                            ]
                          else if (_gameOver)
                            ...[
                              Text(
                                _bricks.isEmpty ? 'You Win!' : 'Game Over!',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: _bricks.isEmpty ? Colors.green : Colors.red,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Final Score: $_score',
                                style: const TextStyle(fontSize: 18, color: Colors.white),
                              ),
                              if (_score == _highScore)
                                const Text(
                                  'New High Score!',
                                  style: TextStyle(fontSize: 16, color: Colors.yellow),
                                ),
                              const SizedBox(height: 24),
                              ElevatedButton(
                                onPressed: _startGame,
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                                child: const Text('Play Again', style: TextStyle(color: Colors.white)),
                              ),
                            ],
                        ],
                      ),
                    ),
                  ),
                
                // Lives indicator
                if (_gameStarted && !_gameOver)
                  Positioned(
                    top: 16,
                    left: 32,
                    child: Row(
                      children: [
                        const Text('Lives: ', style: TextStyle(color: Colors.white, fontSize: 16)),
                        ...List.generate(_lives, (index) => 
                          const Icon(Icons.favorite, color: Colors.red, size: 20)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class Brick {
  final double x, y, width, height;
  final Color color;
  final int points;

  Brick({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.color,
    required this.points,
  });

  bool checkCollision(Offset ballPosition, double ballRadius) {
    return ballPosition.dx + ballRadius > x &&
           ballPosition.dx - ballRadius < x + width &&
           ballPosition.dy + ballRadius > y &&
           ballPosition.dy - ballRadius < y + height;
  }
}

class GamePainter extends CustomPainter {
  final Offset ballPosition;
  final double ballRadius;
  final double paddleX;
  final double paddleWidth;
  final double paddleHeight;
  final List<Brick> bricks;

  GamePainter({
    required this.ballPosition,
    required this.ballRadius,
    required this.paddleX,
    required this.paddleWidth,
    required this.paddleHeight,
    required this.bricks,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();

    // Draw ball
    paint.color = Colors.white;
    canvas.drawCircle(ballPosition, ballRadius, paint);

    // Draw paddle
    paint.color = Colors.blue;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(paddleX, 500, paddleWidth, paddleHeight),
        const Radius.circular(8),
      ),
      paint,
    );

    // Draw bricks
    for (final brick in bricks) {
      paint.color = brick.color;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(brick.x, brick.y, brick.width, brick.height),
          const Radius.circular(4),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}