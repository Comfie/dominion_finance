class Settings {
  final String id;
  final double monthlyIncome;
  final int payday;
  final String currency;
  final double? monthlyBudget;
  final bool notifyBudgetAlerts;
  final bool notifyUpcomingBills;
  final bool notifyPayday;
  final bool notifyGoalProgress;

  Settings({
    required this.id,
    required this.monthlyIncome,
    required this.payday,
    required this.currency,
    this.monthlyBudget,
    required this.notifyBudgetAlerts,
    required this.notifyUpcomingBills,
    required this.notifyPayday,
    required this.notifyGoalProgress,
  });

  factory Settings.fromJson(Map<String, dynamic> json) {
    return Settings(
      id: json['id'] as String,
      monthlyIncome: (json['monthlyIncome'] as num).toDouble(),
      payday: json['payday'] as int,
      currency: json['currency'] as String,
      monthlyBudget: json['monthlyBudget'] != null ? (json['monthlyBudget'] as num).toDouble() : null,
      notifyBudgetAlerts: json['notifyBudgetAlerts'] as bool,
      notifyUpcomingBills: json['notifyUpcomingBills'] as bool,
      notifyPayday: json['notifyPayday'] as bool,
      notifyGoalProgress: json['notifyGoalProgress'] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'monthlyIncome': monthlyIncome,
      'payday': payday,
      'currency': currency,
      if (monthlyBudget != null) 'monthlyBudget': monthlyBudget,
      'notifyBudgetAlerts': notifyBudgetAlerts,
      'notifyUpcomingBills': notifyUpcomingBills,
      'notifyPayday': notifyPayday,
      'notifyGoalProgress': notifyGoalProgress,
    };
  }

  String get currencySymbol {
    switch (currency) {
      case 'ZAR':
        return 'R';
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      default:
        return currency;
    }
  }
}
