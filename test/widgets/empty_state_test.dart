// test/widgets/empty_state_test.dart
import 'package:dominion_app/widgets/empty_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AppEmptyState renders icon, title, and message', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppEmptyState(
            icon: Icons.payments_rounded,
            title: 'No bills yet',
            message: 'Tap + to add your monthly bills',
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byIcon(Icons.payments_rounded), findsOneWidget);
    expect(find.text('No bills yet'), findsOneWidget);
    expect(find.text('Tap + to add your monthly bills'), findsOneWidget);
  });

  testWidgets('AppEmptyState renders an optional action', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppEmptyState(
            icon: Icons.payments_rounded,
            title: 'No bills yet',
            message: 'Tap + to add your monthly bills',
            action: ElevatedButton(onPressed: () {}, child: const Text('Add bill')),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.widgetWithText(ElevatedButton, 'Add bill'), findsOneWidget);
  });

  testWidgets('AppEmptyState fades in over 200ms and holds no widgets back after that', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppEmptyState(
            icon: Icons.inbox_rounded,
            title: 'Empty',
            message: 'Nothing here',
          ),
        ),
      ),
    );

    final fadeFinder = find.byType(FadeTransition);
    expect(fadeFinder, findsOneWidget);

    await tester.pump(const Duration(milliseconds: 200));
    final fade = tester.widget<FadeTransition>(fadeFinder);
    expect(fade.opacity.value, 1.0);
  });
}
