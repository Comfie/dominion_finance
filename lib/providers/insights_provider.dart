import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import 'auth_provider.dart';

class SpendingInsights {
  final String summary;
  final List<String> highlights;
  final List<String> recommendations;
  final String trend;

  SpendingInsights({
    required this.summary,
    required this.highlights,
    required this.recommendations,
    required this.trend,
  });

  factory SpendingInsights.fromJson(Map<String, dynamic> json) {
    return SpendingInsights(
      summary: json['summary'] as String,
      highlights: (json['highlights'] as List).cast<String>(),
      recommendations: (json['recommendations'] as List).cast<String>(),
      trend: json['trend'] as String,
    );
  }
}

class SpendingAnalytics {
  final double totalSpending;
  final double averageDailySpending;
  final List<CategoryBreakdown> categoryBreakdown;
  final List<MonthlyTrend> monthlyTrends;
  final List<String> topCategories;

  SpendingAnalytics({
    required this.totalSpending,
    required this.averageDailySpending,
    required this.categoryBreakdown,
    required this.monthlyTrends,
    required this.topCategories,
  });

  factory SpendingAnalytics.fromJson(Map<String, dynamic> json) {
    return SpendingAnalytics(
      totalSpending: (json['totalSpending'] as num).toDouble(),
      averageDailySpending: (json['averageDailySpending'] as num).toDouble(),
      categoryBreakdown: (json['categoryBreakdown'] as List)
          .map((e) => CategoryBreakdown.fromJson(e as Map<String, dynamic>))
          .toList(),
      monthlyTrends: (json['monthlyTrends'] as List)
          .map((e) => MonthlyTrend.fromJson(e as Map<String, dynamic>))
          .toList(),
      topCategories: (json['topCategories'] as List).cast<String>(),
    );
  }
}

class CategoryBreakdown {
  final String category;
  final double amount;
  final double percentage;

  CategoryBreakdown({
    required this.category,
    required this.amount,
    required this.percentage,
  });

  factory CategoryBreakdown.fromJson(Map<String, dynamic> json) {
    return CategoryBreakdown(
      category: json['category'] as String,
      amount: (json['amount'] as num).toDouble(),
      percentage: (json['percentage'] as num).toDouble(),
    );
  }
}

class MonthlyTrend {
  final String month;
  final double totalExpenses;
  final double totalIncome;
  final double netCashFlow;

  MonthlyTrend({
    required this.month,
    required this.totalExpenses,
    required this.totalIncome,
    required this.netCashFlow,
  });

  factory MonthlyTrend.fromJson(Map<String, dynamic> json) {
    return MonthlyTrend(
      month: json['month'] as String,
      totalExpenses: (json['totalExpenses'] as num).toDouble(),
      totalIncome: (json['totalIncome'] as num).toDouble(),
      netCashFlow: (json['netCashFlow'] as num).toDouble(),
    );
  }
}

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
  late final ApiClient _apiClient;

  @override
  InsightsState build() {
    _apiClient = ref.read(apiClientProvider);
    return InsightsState();
  }

  Future<void> loadInsights({String? month}) async {
    state = state.copyWith(isLoadingInsights: true, error: null);
    try {
      final response = await _apiClient.getInsights(month: month);
      if (response.statusCode == 200) {
        final insights = SpendingInsights.fromJson(response.data as Map<String, dynamic>);
        state = state.copyWith(insights: insights, isLoadingInsights: false);
      } else {
        state = state.copyWith(isLoadingInsights: false, error: 'Failed to load insights');
      }
    } catch (e) {
      state = state.copyWith(isLoadingInsights: false, error: 'Failed to load insights');
    }
  }

  Future<void> loadAnalytics({int? months, String? targetMonth}) async {
    state = state.copyWith(isLoadingAnalytics: true, error: null);
    try {
      final response = await _apiClient.getSpendingAnalytics(
        months: months,
        targetMonth: targetMonth,
      );
      if (response.statusCode == 200) {
        final analytics = SpendingAnalytics.fromJson(response.data as Map<String, dynamic>);
        state = state.copyWith(analytics: analytics, isLoadingAnalytics: false);
      } else {
        state = state.copyWith(isLoadingAnalytics: false, error: 'Failed to load analytics');
      }
    } catch (e) {
      state = state.copyWith(isLoadingAnalytics: false, error: 'Failed to load analytics');
    }
  }

  Future<void> loadAll({String? month}) async {
    await Future.wait([
      loadInsights(month: month),
      loadAnalytics(targetMonth: month),
    ]);
  }
}

final insightsProvider = NotifierProvider<InsightsNotifier, InsightsState>(
  InsightsNotifier.new,
);
