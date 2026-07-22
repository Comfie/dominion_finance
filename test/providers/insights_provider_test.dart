import 'package:dominion_app/providers/insights_provider.dart';
import 'package:dominion_app/repositories/ai_repository.dart';
import 'package:dominion_app/repositories/repository_exception.dart';
import 'package:dominion_app/repositories/repository_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeAiRepository implements AiRepository {
  SpendingInsights? insightsToReturn;
  SpendingAnalytics? analyticsToReturn;
  bool throwOnInsights = false;
  bool throwOnAnalytics = false;

  @override
  Future<ScannedReceipt> scanReceipt(String imageBase64, String mimeType) {
    throw UnimplementedError('not used by these tests');
  }

  @override
  Future<SpendingInsights> getInsights({String? month}) async {
    if (throwOnInsights) throw const RepositoryException('Failed to load insights');
    return insightsToReturn!;
  }

  @override
  Future<SpendingAnalytics> getSpendingAnalytics({int? months, String? targetMonth}) async {
    if (throwOnAnalytics) throw const RepositoryException('Failed to load spending analytics');
    return analyticsToReturn!;
  }
}

void main() {
  group('InsightsNotifier', () {
    test('loadInsights populates state on success', () async {
      final fake = FakeAiRepository()
        ..insightsToReturn = SpendingInsights(
          summary: 'You spent 12% less this month.',
          highlights: ['Groceries down 8%'],
          recommendations: ['Consider a dining budget'],
          trend: 'improving',
        );
      final container = ProviderContainer(
        overrides: [aiRepositoryProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);

      await container.read(insightsProvider.notifier).loadInsights();

      final state = container.read(insightsProvider);
      expect(state.isLoadingInsights, false);
      expect(state.error, isNull);
      expect(state.insights!.summary, 'You spent 12% less this month.');
      expect(state.insights!.trend, 'improving');
    });

    test('loadInsights sets error on failure', () async {
      final fake = FakeAiRepository()..throwOnInsights = true;
      final container = ProviderContainer(
        overrides: [aiRepositoryProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);

      await container.read(insightsProvider.notifier).loadInsights();

      final state = container.read(insightsProvider);
      expect(state.isLoadingInsights, false);
      expect(state.error, 'Failed to load insights');
      expect(state.insights, isNull);
    });

    test('loadAnalytics populates state on success', () async {
      final fake = FakeAiRepository()
        ..analyticsToReturn = SpendingAnalytics(
          totalSpending: 4200.0,
          averageDailySpending: 140.0,
          categoryBreakdown: [
            CategoryBreakdown(category: 'GROCERIES', amount: 1200.0, percentage: 28.5),
          ],
          monthlyTrends: [
            MonthlyTrend(month: 'Jul', totalExpenses: 4200.0, totalIncome: 15000.0, netCashFlow: 10800.0),
          ],
          topCategories: ['GROCERIES'],
        );
      final container = ProviderContainer(
        overrides: [aiRepositoryProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);

      await container.read(insightsProvider.notifier).loadAnalytics();

      final state = container.read(insightsProvider);
      expect(state.isLoadingAnalytics, false);
      expect(state.error, isNull);
      expect(state.analytics!.totalSpending, 4200.0);
      expect(state.analytics!.monthlyTrends.single.month, 'Jul');
    });

    test('loadAnalytics sets error on failure', () async {
      final fake = FakeAiRepository()..throwOnAnalytics = true;
      final container = ProviderContainer(
        overrides: [aiRepositoryProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);

      await container.read(insightsProvider.notifier).loadAnalytics();

      final state = container.read(insightsProvider);
      expect(state.isLoadingAnalytics, false);
      expect(state.error, 'Failed to load spending analytics');
    });

    test('loadAll loads both insights and analytics', () async {
      final fake = FakeAiRepository()
        ..insightsToReturn = SpendingInsights(
          summary: 'Summary',
          highlights: const [],
          recommendations: const [],
          trend: 'stable',
        )
        ..analyticsToReturn = SpendingAnalytics(
          totalSpending: 100.0,
          averageDailySpending: 3.3,
          categoryBreakdown: const [],
          monthlyTrends: const [],
          topCategories: const [],
        );
      final container = ProviderContainer(
        overrides: [aiRepositoryProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);

      await container.read(insightsProvider.notifier).loadAll();

      final state = container.read(insightsProvider);
      expect(state.insights, isNotNull);
      expect(state.analytics, isNotNull);
    });
  });
}
