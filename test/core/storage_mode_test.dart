import 'package:dominion_app/core/storage_mode.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// In-memory fake so the notifier can be tested without touching platform
/// channels (flutter_secure_storage requires a real platform).
class FakeStorageModeStore implements StorageModeStore {
  String? stored;

  FakeStorageModeStore([this.stored]);

  @override
  Future<String?> read() async => stored;

  @override
  Future<void> write(String value) async {
    stored = value;
  }
}

void main() {
  group('StorageModeNotifier', () {
    test('defaults to cloud before load()', () {
      final container = ProviderContainer(
        overrides: [
          storageModeStoreProvider.overrideWithValue(FakeStorageModeStore()),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(storageModeProvider), StorageMode.cloud);
    });

    test('load() reads a persisted local mode', () async {
      final container = ProviderContainer(
        overrides: [
          storageModeStoreProvider.overrideWithValue(
            FakeStorageModeStore('local'),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(storageModeProvider.notifier).load();

      expect(container.read(storageModeProvider), StorageMode.local);
    });

    test('load() with no persisted value falls back to cloud', () async {
      final container = ProviderContainer(
        overrides: [
          storageModeStoreProvider.overrideWithValue(FakeStorageModeStore()),
        ],
      );
      addTearDown(container.dispose);

      await container.read(storageModeProvider.notifier).load();

      expect(container.read(storageModeProvider), StorageMode.cloud);
    });

    test('load() with a garbage persisted value falls back to cloud', () async {
      final container = ProviderContainer(
        overrides: [
          storageModeStoreProvider.overrideWithValue(
            FakeStorageModeStore('nonsense'),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(storageModeProvider.notifier).load();

      expect(container.read(storageModeProvider), StorageMode.cloud);
    });

    test('setMode() updates state and persists the choice', () async {
      final store = FakeStorageModeStore();
      final container = ProviderContainer(
        overrides: [storageModeStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);

      await container.read(storageModeProvider.notifier).setMode(StorageMode.local);

      expect(container.read(storageModeProvider), StorageMode.local);
      expect(store.stored, 'local');
    });
  });
}
