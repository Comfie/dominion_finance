import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/storage_mode.dart';
import '../data/local/database.dart';
import '../providers/auth_provider.dart' show apiClientProvider;
import 'ai_repository.dart';
import 'expenses_repository.dart';
import 'goals_repository.dart';
import 'incomes_repository.dart';
import 'local/local_expenses_repository.dart';
import 'local/local_goals_repository.dart';
import 'local/local_incomes_repository.dart';
import 'local/local_obligations_repository.dart';
import 'local/local_persons_repository.dart';
import 'local/local_settings_repository.dart';
import 'obligations_repository.dart';
import 'persons_repository.dart';
import 'remote/remote_ai_repository.dart';
import 'remote/remote_expenses_repository.dart';
import 'remote/remote_goals_repository.dart';
import 'remote/remote_incomes_repository.dart';
import 'remote/remote_obligations_repository.dart';
import 'remote/remote_persons_repository.dart';
import 'remote/remote_settings_repository.dart';
import 'settings_repository.dart';

/// Wires each repository interface to its Remote (HTTP) or Local
/// (Drift/SQLite) implementation depending on [storageModeProvider]. Cloud
/// mode's behavior is unchanged from before local-first support existed.
final expensesRepositoryProvider = Provider<ExpensesRepository>((ref) {
  if (ref.watch(storageModeProvider) == StorageMode.local) {
    return ref.watch(localExpensesRepositoryProvider);
  }
  return RemoteExpensesRepository(ref.read(apiClientProvider));
});

final incomesRepositoryProvider = Provider<IncomesRepository>((ref) {
  if (ref.watch(storageModeProvider) == StorageMode.local) {
    return ref.watch(localIncomesRepositoryProvider);
  }
  return RemoteIncomesRepository(ref.read(apiClientProvider));
});

final obligationsRepositoryProvider = Provider<ObligationsRepository>((ref) {
  if (ref.watch(storageModeProvider) == StorageMode.local) {
    return ref.watch(localObligationsRepositoryProvider);
  }
  return RemoteObligationsRepository(ref.read(apiClientProvider));
});

final goalsRepositoryProvider = Provider<GoalsRepository>((ref) {
  if (ref.watch(storageModeProvider) == StorageMode.local) {
    return ref.watch(localGoalsRepositoryProvider);
  }
  return RemoteGoalsRepository(ref.read(apiClientProvider));
});

final personsRepositoryProvider = Provider<PersonsRepository>((ref) {
  if (ref.watch(storageModeProvider) == StorageMode.local) {
    return ref.watch(localPersonsRepositoryProvider);
  }
  return RemotePersonsRepository(ref.read(apiClientProvider));
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  if (ref.watch(storageModeProvider) == StorageMode.local) {
    return ref.watch(localSettingsRepositoryProvider);
  }
  return RemoteSettingsRepository(ref.read(apiClientProvider));
});

/// AI features (receipt scanning, spending insights) always require the
/// remote API and an account - there is no local implementation. UI entry
/// points gate on [storageModeProvider] before reaching this provider.
final aiRepositoryProvider = Provider<AiRepository>((ref) {
  return RemoteAiRepository(ref.read(apiClientProvider));
});

/// The local (Drift/SQLite) database backing the `local<Domain>Repository`
/// providers below, used when [storageModeProvider] is [StorageMode.local].
final databaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

final localExpensesRepositoryProvider = Provider<ExpensesRepository>((ref) {
  return LocalExpensesRepository(ref.read(databaseProvider));
});

final localIncomesRepositoryProvider = Provider<IncomesRepository>((ref) {
  return LocalIncomesRepository(ref.read(databaseProvider));
});

final localObligationsRepositoryProvider = Provider<ObligationsRepository>((ref) {
  return LocalObligationsRepository(ref.read(databaseProvider));
});

final localGoalsRepositoryProvider = Provider<GoalsRepository>((ref) {
  return LocalGoalsRepository(ref.read(databaseProvider));
});

final localPersonsRepositoryProvider = Provider<PersonsRepository>((ref) {
  return LocalPersonsRepository(ref.read(databaseProvider));
});

final localSettingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return LocalSettingsRepository(ref.read(databaseProvider));
});
