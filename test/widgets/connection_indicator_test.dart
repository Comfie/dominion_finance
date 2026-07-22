import 'package:dominion_app/core/storage_mode.dart';
import 'package:dominion_app/widgets/connection_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Returns a fixed [StorageMode] without ever touching secure storage —
/// build() never calls super.build(), so the notifier never reads
/// storageModeStoreProvider.
class _FixedStorageModeNotifier extends StorageModeNotifier {
  _FixedStorageModeNotifier(this._value);
  final StorageMode _value;

  @override
  StorageMode build() => _value;
}

void main() {
  testWidgets(
    'renders only the child and never touches connectivity in local mode',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storageModeProvider.overrideWith(
              () => _FixedStorageModeNotifier(StorageMode.local),
            ),
          ],
          child: const MaterialApp(
            home: ConnectionIndicator(child: Text('body')),
          ),
        ),
      );

      // If local mode ever started listening to Connectivity, the plugin
      // would throw MissingPluginException in the test harness — pumping
      // without a thrown exception is itself part of what this asserts.
      await tester.pump();

      expect(find.text('body'), findsOneWidget);
      expect(find.byIcon(Icons.wifi_off_rounded), findsNothing);
      expect(find.byIcon(Icons.wifi_rounded), findsNothing);
    },
  );
}
