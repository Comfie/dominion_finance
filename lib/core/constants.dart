class AppConstants {
  static const String appName = 'Dominion';
  static const String apiBaseUrl = 'http://localhost:5000/api';

  // Storage keys
  static const String tokenKey = 'auth_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userKey = 'user_data';

  // Date formats
  static const String monthFormat = 'yyyy-MM';
  static const String dateFormat = 'yyyy-MM-dd';
  static const String displayDateFormat = 'dd MMM yyyy';
  static const String displayMonthFormat = 'MMMM yyyy';
}

enum Category {
  HOUSING,
  DEBT,
  LIVING,
  SAVINGS,
  INSURANCE,
  UTILITIES,
  TRANSPORT,
  GROCERIES,
  OTHER,
  DINING,
  ENTERTAINMENT,
  SHOPPING;

  String get displayName {
    switch (this) {
      case Category.HOUSING:
        return 'Housing';
      case Category.DEBT:
        return 'Debt';
      case Category.LIVING:
        return 'Living';
      case Category.SAVINGS:
        return 'Savings';
      case Category.INSURANCE:
        return 'Insurance';
      case Category.UTILITIES:
        return 'Utilities';
      case Category.TRANSPORT:
        return 'Transport';
      case Category.GROCERIES:
        return 'Groceries';
      case Category.OTHER:
        return 'Other';
      case Category.DINING:
        return 'Dining';
      case Category.ENTERTAINMENT:
        return 'Entertainment';
      case Category.SHOPPING:
        return 'Shopping';
    }
  }

  String get color {
    switch (this) {
      case Category.HOUSING:
        return '#3B82F6';
      case Category.DEBT:
        return '#EF4444';
      case Category.LIVING:
        return '#10B981';
      case Category.SAVINGS:
        return '#8B5CF6';
      case Category.INSURANCE:
        return '#F59E0B';
      case Category.UTILITIES:
        return '#6366F1';
      case Category.TRANSPORT:
        return '#EC4899';
      case Category.GROCERIES:
        return '#14B8A6';
      case Category.OTHER:
        return '#6B7280';
      case Category.DINING:
        return '#F97316';
      case Category.ENTERTAINMENT:
        return '#A855F7';
      case Category.SHOPPING:
        return '#06B6D4';
    }
  }
}

enum IncomeSource {
  SALARY,
  FREELANCE,
  SIDE_HUSTLE,
  SALE,
  RENTAL,
  GIFT,
  INVESTMENT,
  REFUND,
  BUSINESS,
  OTHER;

  String get displayName {
    switch (this) {
      case IncomeSource.SALARY:
        return 'Salary';
      case IncomeSource.FREELANCE:
        return 'Freelance';
      case IncomeSource.SIDE_HUSTLE:
        return 'Side Hustle';
      case IncomeSource.SALE:
        return 'Sale';
      case IncomeSource.RENTAL:
        return 'Rental';
      case IncomeSource.GIFT:
        return 'Gift';
      case IncomeSource.INVESTMENT:
        return 'Investment';
      case IncomeSource.REFUND:
        return 'Refund';
      case IncomeSource.BUSINESS:
        return 'Business';
      case IncomeSource.OTHER:
        return 'Other';
    }
  }
}

enum GoalCategory {
  EMERGENCY_FUND,
  HOLIDAY,
  CAR,
  HOME,
  EDUCATION,
  WEDDING,
  RETIREMENT,
  OTHER;

  String get displayName {
    switch (this) {
      case GoalCategory.EMERGENCY_FUND:
        return 'Emergency Fund';
      case GoalCategory.HOLIDAY:
        return 'Holiday';
      case GoalCategory.CAR:
        return 'Car';
      case GoalCategory.HOME:
        return 'Home';
      case GoalCategory.EDUCATION:
        return 'Education';
      case GoalCategory.WEDDING:
        return 'Wedding';
      case GoalCategory.RETIREMENT:
        return 'Retirement';
      case GoalCategory.OTHER:
        return 'Other';
    }
  }
}

// Expense category enum - used for expense categorization
enum ExpenseCategory {
  HOUSING,
  DEBT,
  LIVING,
  SAVINGS,
  INSURANCE,
  UTILITIES,
  TRANSPORT,
  GROCERIES,
  OTHER,
  DINING,
  ENTERTAINMENT,
  SHOPPING;

  String get displayName {
    switch (this) {
      case ExpenseCategory.HOUSING:
        return 'Housing';
      case ExpenseCategory.DEBT:
        return 'Debt';
      case ExpenseCategory.LIVING:
        return 'Living';
      case ExpenseCategory.SAVINGS:
        return 'Savings';
      case ExpenseCategory.INSURANCE:
        return 'Insurance';
      case ExpenseCategory.UTILITIES:
        return 'Utilities';
      case ExpenseCategory.TRANSPORT:
        return 'Transport';
      case ExpenseCategory.GROCERIES:
        return 'Groceries';
      case ExpenseCategory.OTHER:
        return 'Other';
      case ExpenseCategory.DINING:
        return 'Dining';
      case ExpenseCategory.ENTERTAINMENT:
        return 'Entertainment';
      case ExpenseCategory.SHOPPING:
        return 'Shopping';
    }
  }

  String get color {
    switch (this) {
      case ExpenseCategory.HOUSING:
        return '#3B82F6';
      case ExpenseCategory.DEBT:
        return '#EF4444';
      case ExpenseCategory.LIVING:
        return '#10B981';
      case ExpenseCategory.SAVINGS:
        return '#8B5CF6';
      case ExpenseCategory.INSURANCE:
        return '#F59E0B';
      case ExpenseCategory.UTILITIES:
        return '#6366F1';
      case ExpenseCategory.TRANSPORT:
        return '#EC4899';
      case ExpenseCategory.GROCERIES:
        return '#14B8A6';
      case ExpenseCategory.OTHER:
        return '#6B7280';
      case ExpenseCategory.DINING:
        return '#F97316';
      case ExpenseCategory.ENTERTAINMENT:
        return '#A855F7';
      case ExpenseCategory.SHOPPING:
        return '#06B6D4';
    }
  }
}
