// test/widgets/error_state_test.dart
import 'package:dominion_app/widgets/error_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AppErrorState shows a default message and no action by default', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AppErrorState())),
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Something went wrong'), findsOneWidget);
    expect(find.text('An unexpected error occurred. Please try again.'), findsOneWidget);
    expect(find.byType(ElevatedButton), findsNothing);
  });

  testWidgets('AppErrorState shows a custom message', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AppErrorState(message: 'Could not load your bills.')),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Could not load your bills.'), findsOneWidget);
  });

  testWidgets('AppErrorState shows and invokes a retry action', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AppErrorState(onRetry: () => retried = true)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    // `ElevatedButton.icon` returns `_ElevatedButtonWithIcon`, a subclass of
    // `ElevatedButton` — `find.byType`/`find.widgetWithText` match by exact
    // runtime type and won't find it, so match by `is ElevatedButton` instead.
    final buttonFinder = find.byWidgetPredicate((widget) => widget is ElevatedButton);
    expect(buttonFinder, findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);

    await tester.tap(buttonFinder);
    await tester.pump();

    expect(retried, isTrue);
  });

  testWidgets('AppErrorState colors the icon with the error color', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(colorScheme: const ColorScheme.light(error: Colors.deepOrange)),
        home: const Scaffold(body: AppErrorState()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    final icon = tester.widget<Icon>(find.byIcon(Icons.error_outline_rounded));
    expect(icon.color, Colors.deepOrange);
  });
}
