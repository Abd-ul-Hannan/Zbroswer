import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zbrowser/games/snake_game.dart';

void main() {
  testWidgets('Snake game should render without errors', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SnakeGame(),
      ),
    );

    expect(find.text('Snake Game'), findsOneWidget);
    expect(find.text('Score: 0'), findsOneWidget);
    expect(find.byType(GridView), findsOneWidget);
  });

  testWidgets('Snake game should have control buttons', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SnakeGame(),
      ),
    );


    expect(find.byIcon(Icons.keyboard_arrow_up), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_arrow_left), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_arrow_right), findsOneWidget);
  });
}