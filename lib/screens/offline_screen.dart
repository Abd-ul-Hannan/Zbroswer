import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/connectivity_controller.dart';
import '../games/snake_game.dart';
import '../games/brick_breaker_game.dart';

class OfflineScreen extends StatelessWidget {
  const OfflineScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Offline Icon
            const Icon(
              Icons.wifi_off_rounded,
              size: 80,
              color: Colors.white70,
            ),
            const SizedBox(height: 24),
            
            // Main Message
            const Text(
              'No Internet Connection',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            
            // Subtitle
            const Text(
              'While you\'re offline, play a game 🎮',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            
            // Game Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                      _buildGameButton(
                        'Play Snake',
                        Icons.grid_4x4_rounded,
                        Colors.green,
                        () => Get.to(() => const SnakeGame()),
                      ),
                      const SizedBox(height: 16),
                      _buildGameButton(
                        'Play Brick Breaker',
                        Icons.sports_baseball_rounded,
                        Colors.orange,
                        () => Get.to(() => const BrickBreakerGame()),
                      ),
                ],
              ),
            ),
            const SizedBox(height: 48),
            
            // Retry Connection
            TextButton.icon(
              onPressed: () {
                final controller = Get.find<ConnectivityController>();
                controller.checkConnectivity();
              },
              icon: const Icon(Icons.refresh, color: Colors.blue),
              label: const Text(
                'Try Again',
                style: TextStyle(color: Colors.blue),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameButton(String title, IconData icon, Color color, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: Colors.white),
        label: Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
        ),
      ),
    );
  }
}