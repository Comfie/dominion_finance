import 'package:dominion_app/widgets/cards/app_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AppCard renders its child', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AppCard(child: Text('content'))),
      ),
    );

    expect(find.text('content'), findsOneWidget);
  });

  testWidgets('AppCard invokes onTap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppCard(
            onTap: () => tapped = true,
            child: const Text('content'),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(AppCard));
    await tester.pump();

    expect(tapped, isTrue);
  });

  testWidgets('AppCard defaults to colorScheme.surface', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(colorScheme: const ColorScheme.light(surface: Colors.pink)),
        home: const Scaffold(body: AppCard(child: Text('content'))),
      ),
    );

    final material = tester.widget<Material>(
      find.descendant(of: find.byType(AppCard), matching: find.byType(Material)).first,
    );
    expect(material.color, Colors.pink);
  });

  testWidgets('AppCard honors an explicit color override', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AppCard(color: Colors.teal, child: Text('content'))),
      ),
    );

    final material = tester.widget<Material>(
      find.descendant(of: find.byType(AppCard), matching: find.byType(Material)).first,
    );
    expect(material.color, Colors.teal);
  });
}
