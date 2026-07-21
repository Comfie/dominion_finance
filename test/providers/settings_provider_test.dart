import 'package:drift/native.dart';
import 'package:dominion_app/data/local/database.dart';
import 'package:dominion_app/providers/settings_provider.dart';
import 'package:dominion_app/repositories/local/local_settings_repository.dart';
import 'package:dominion_app/repositories/repository_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late ProviderContainer container;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(LocalSettingsRepository(database)),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await database.close();
  });

  test('loadSettings populates state with the persisted defaults', () async {
    await container.read(settingsProvider.notifier).loadSettings();

    final state = container.read(settingsProvider);
    expect(state.isLoading, false);
    expect(state.error, isNull);
    expect(state.settings, isNotNull);
    expect(state.settings!.monthlyIncome, 0);
    expect(state.settings!.payday, 25);
    expect(state.settings!.currency, 'ZAR');
  });

  test('updateSettings persists changes and reflects them in state', () async {
    await container.read(settingsProvider.notifier).loadSettings();

    final success = await container.read(settingsProvider.notifier).updateSettings({
      'monthlyIncome': 15000.0,
      'payday': 1,
    });

    expect(success, true);
    final state = container.read(settingsProvider);
    expect(state.settings!.monthlyIncome, 15000.0);
    expect(state.settings!.payday, 1);
    // Fields not included in the update are left untouched.
    expect(state.settings!.currency, 'ZAR');
  });
}
