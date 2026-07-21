import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where the app reads/writes its data.
///
/// [cloud] talks to the remote API and requires a signed-in account.
/// [local] keeps everything in the on-device Drift database - no account,
/// no network calls for domain data.
enum StorageMode {
  cloud,
  local;

  static StorageMode fromName(String? name) {
    return StorageMode.values.firstWhere(
      (mode) => mode.name == name,
      orElse: () => StorageMode.cloud,
    );
  }
}

/// Thin storage seam so [StorageModeNotifier] can be tested without touching
/// platform channels (flutter_secure_storage requires a real platform).
abstract class StorageModeStore {
  Future<String?> read();

  Future<void> write(String value);
}

/// Default [StorageModeStore] backed by the same flutter_secure_storage
/// instance used elsewhere in the app (e.g. [ApiClient], `AuthNotifier`).
class SecureStorageModeStore implements StorageModeStore {
  static const String key = 'storage_mode';

  final FlutterSecureStorage _storage;

  const SecureStorageModeStore([this._storage = const FlutterSecureStorage()]);

  @override
  Future<String?> read() => _storage.read(key: key);

  @override
  Future<void> write(String value) => _storage.write(key: key, value: value);
}

final storageModeStoreProvider = Provider<StorageModeStore>((ref) {
  return const SecureStorageModeStore();
});

/// Holds the current [StorageMode] and persists changes via
/// [storageModeStoreProvider].
///
/// The persisted value must be loaded (via [load]) before the router makes
/// its first redirect decision, otherwise a local-mode user would briefly
/// see the login screen on cold start. `main()` does this before `runApp`.
class StorageModeNotifier extends Notifier<StorageMode> {
  late final StorageModeStore _store;

  @override
  StorageMode build() {
    _store = ref.read(storageModeStoreProvider);
    return StorageMode.cloud;
  }

  /// Reads the persisted mode and updates state. Safe to call multiple
  /// times; intended to be awaited once during app startup.
  Future<void> load() async {
    final raw = await _store.read();
    state = StorageMode.fromName(raw);
  }

  /// Switches the active mode and persists the choice.
  Future<void> setMode(StorageMode mode) async {
    state = mode;
    await _store.write(mode.name);
  }
}

final storageModeProvider = NotifierProvider<StorageModeNotifier, StorageMode>(
  StorageModeNotifier.new,
);
