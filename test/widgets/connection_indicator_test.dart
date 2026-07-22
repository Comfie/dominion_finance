import 'package:dominion_app/core/storage_mode.dart';
import 'package:dominion_app/widgets/connection_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      // connectivity_plus's checkConnectivity() calls
      // MethodChannel('dev.fluttercommunity.plus/connectivity').invokeListMethod('check').
      // Registering a mock handler lets this test tell old vs. new behavior
      // apart: the pre-rewrite widget calls this unconditionally in
      // initState, regardless of storage mode, so this flag would flip to
      // true against the old code too — the EventChannel used for
      // onConnectivityChanged does NOT throw when unhandled in tests, which
      // is why an earlier version of this test (asserting only "no thrown
      // exception") passed against both the old and new widget and caught
      // nothing.
      var checkInvoked = false;
      const channel = MethodChannel('dev.fluttercommunity.plus/connectivity');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'check') checkInvoked = true;
        return <String>['wifi'];
      });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });

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

      await tester.pump();

      expect(find.text('body'), findsOneWidget);
      expect(find.byIcon(Icons.wifi_off_rounded), findsNothing);
      expect(find.byIcon(Icons.wifi_rounded), findsNothing);
      expect(
        checkInvoked,
        isFalse,
        reason: 'ConnectionIndicator must never call '
            'Connectivity.checkConnectivity() in local mode',
      );
    },
  );
}
