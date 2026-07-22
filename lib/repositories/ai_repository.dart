/// Result of an AI receipt scan: best-effort extracted fields for the user
/// to review before creating an expense from them.
class ScannedReceipt {
  final String? name;
  final double? amount;
  final String? category;

  ScannedReceipt({this.name, this.amount, this.category});

  factory ScannedReceipt.fromJson(Map<String, dynamic> json) {
    return ScannedReceipt(
      name: json['name'] as String?,
      amount: (json['amount'] as num?)?.toDouble(),
      category: json['category'] as String?,
    );
  }
}

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

class CategoryBreakdown {
  final String category;
  final double amount;
  final double percentage;

  CategoryBreakdown({required this.category, required this.amount, required this.percentage});

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

/// Abstract data access for AI-powered features. These always require the
/// remote API and an account - there is no on-device implementation, so
/// callers must gate access to this repository behind [StorageMode.cloud]
/// (see `storage_mode.dart`).
abstract class AiRepository {
  Future<ScannedReceipt> scanReceipt(String imageBase64, String mimeType);
  Future<SpendingInsights> getInsights({String? month});
  Future<SpendingAnalytics> getSpendingAnalytics({int? months, String? targetMonth});
}
