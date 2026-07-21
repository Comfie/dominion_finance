import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/settings.dart';
import '../repositories/repository_providers.dart';
import '../repositories/settings_repository.dart';

class SettingsState {
  final Settings? settings;
  final bool isLoading;
  final String? error;

  SettingsState({
    this.settings,
    this.isLoading = false,
    this.error,
  });

  SettingsState copyWith({
    Settings? settings,
    bool? isLoading,
    String? error,
  }) {
    return SettingsState(
      settings: settings ?? this.settings,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class SettingsNotifier extends Notifier<SettingsState> {
  late final SettingsRepository _repository;

  @override
  SettingsState build() {
    _repository = ref.read(settingsRepositoryProvider);
    return SettingsState();
  }

  Future<void> loadSettings() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final settings = await _repository.getSettings();
      state = state.copyWith(settings: settings, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Failed to load settings');
    }
  }

  Future<bool> updateSettings(Map<String, dynamic> data) async {
    try {
      final settings = await _repository.updateSettings(data);
      state = state.copyWith(settings: settings);
      return true;
    } catch (e) {
      return false;
    }
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(
  SettingsNotifier.new,
);
