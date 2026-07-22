import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/ai_repository.dart';
import '../repositories/repository_exception.dart';
import '../repositories/repository_providers.dart';

class InsightsState {
  final SpendingInsights? insights;
  final SpendingAnalytics? analytics;
  final bool isLoadingInsights;
  final bool isLoadingAnalytics;
  final String? error;

  InsightsState({
    this.insights,
    this.analytics,
    this.isLoadingInsights = false,
    this.isLoadingAnalytics = false,
    this.error,
  });

  InsightsState copyWith({
    SpendingInsights? insights,
    SpendingAnalytics? analytics,
    bool? isLoadingInsights,
    bool? isLoadingAnalytics,
    String? error,
  }) {
    return InsightsState(
      insights: insights ?? this.insights,
      analytics: analytics ?? this.analytics,
      isLoadingInsights: isLoadingInsights ?? this.isLoadingInsights,
      isLoadingAnalytics: isLoadingAnalytics ?? this.isLoadingAnalytics,
      error: error,
    );
  }
}

class InsightsNotifier extends Notifier<InsightsState> {
  late final AiRepository _aiRepository;

  @override
  InsightsState build() {
    _aiRepository = ref.read(aiRepositoryProvider);
    return InsightsState();
  }

  Future<void> loadInsights({String? month}) async {
    state = state.copyWith(isLoadingInsights: true, error: null);
    try {
      final insights = await _aiRepository.getInsights(month: month);
      state = state.copyWith(insights: insights, isLoadingInsights: false, error: state.error);
    } on RepositoryException catch (e) {
      state = state.copyWith(isLoadingInsights: false, error: e.message);
    }
  }

  Future<void> loadAnalytics({int? months, String? targetMonth}) async {
    state = state.copyWith(isLoadingAnalytics: true, error: null);
    try {
      final analytics = await _aiRepository.getSpendingAnalytics(months: months, targetMonth: targetMonth);
      state = state.copyWith(analytics: analytics, isLoadingAnalytics: false, error: state.error);
    } on RepositoryException catch (e) {
      state = state.copyWith(isLoadingAnalytics: false, error: e.message);
    }
  }

  Future<void> loadAll({String? month}) async {
    await Future.wait([loadInsights(month: month), loadAnalytics(targetMonth: month)]);
  }
}

final insightsProvider = NotifierProvider<InsightsNotifier, InsightsState>(
  InsightsNotifier.new,
);
