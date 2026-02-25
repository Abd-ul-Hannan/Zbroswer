import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:zbrowser/controllers/connectivity_controller.dart';
import 'package:zbrowser/screens/offline_screen.dart';
import 'package:zbrowser/games/snake_game.dart';
import 'package:zbrowser/games/brick_breaker_game.dart';

void main() {
  group('Offline Mode Tests', () {
    setUp(() {
      Get.reset();
      Get.put(ConnectivityController());
    });

    testWidgets('Offline screen should render correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        GetMaterialApp(
          home: const OfflineScreen(),
        ),
      );

      expect(find.text('No Internet Connection'), findsOneWidget);
      expect(find.text('While you\'re offline, play a game 🎮'), findsOneWidget);
      expect(find.text('Play Snake'), findsOneWidget);
      expect(find.text('Play Brick Breaker'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);
      expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
    });

    testWidgets('Snake game button should navigate to snake game', (WidgetTester tester) async {
      await tester.pumpWidget(
        GetMaterialApp(
          home: const OfflineScreen(),
          getPages: [
            GetPage(name: '/snake', page: () => const SnakeGame()),
          ],
        ),
      );

      await tester.tap(find.text('Play Snake'));
      await tester.pumpAndSettle();

      expect(find.text('Snake Game'), findsOneWidget);
    });

    testWidgets('Brick Breaker button should navigate to brick breaker game', (WidgetTester tester) async {
      await tester.pumpWidget(
        GetMaterialApp(
          home: const OfflineScreen(),
          getPages: [
            GetPage(name: '/brickbreaker', page: () => const BrickBreakerGame()),
          ],
        ),
      );

      await tester.tap(find.text('Play Brick Breaker'));
      await tester.pumpAndSettle();

      expect(find.text('Brick Breaker'), findsOneWidget);
    });

    testWidgets('Try Again button should trigger connectivity check', (WidgetTester tester) async {
      final connectivityController = Get.find<ConnectivityController>();
      
      await tester.pumpWidget(
        GetMaterialApp(
          home: const OfflineScreen(),
        ),
      );

      await tester.tap(find.text('Try Again'));
      await tester.pump();

      // Verify that the connectivity check was triggered
      expect(connectivityController.isChecking.value, isTrue);
    });
  });

  group('Game Tests', () {
    testWidgets('Snake game should have start game overlay', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: const SnakeGame(),
        ),
      );

      expect(find.text('Snake Game'), findsOneWidget);
      expect(find.text('Use arrow keys or swipe to control the snake'), findsOneWidget);
      expect(find.text('Start Game'), findsOneWidget);
    });

    testWidgets('Brick Breaker game should have start game overlay', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: const BrickBreakerGame(),
        ),
      );

      expect(find.text('Brick Breaker'), findsOneWidget);
      expect(find.text('Use arrow keys or swipe to move paddle'), findsOneWidget);
      expect(find.text('Start Game'), findsOneWidget);
    });
  });
}