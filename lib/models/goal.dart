import '../core/constants.dart';

class SavingsGoal {
  final String id;
  final String name;
  final double targetAmount;
  final double currentAmount;
  final DateTime? targetDate;
  final GoalCategory category;
  final String color;
  final bool isCompleted;
  final double progressPercentage;
  final DateTime createdAt;
  final DateTime updatedAt;

  SavingsGoal({
    required this.id,
    required this.name,
    required this.targetAmount,
    required this.currentAmount,
    this.targetDate,
    required this.category,
    required this.color,
    required this.isCompleted,
    required this.progressPercentage,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SavingsGoal.fromJson(Map<String, dynamic> json) {
    return SavingsGoal(
      id: json['id'] as String,
      name: json['name'] as String,
      targetAmount: (json['targetAmount'] as num).toDouble(),
      currentAmount: (json['currentAmount'] as num).toDouble(),
      targetDate: json['targetDate'] != null ? DateTime.parse(json['targetDate'] as String) : null,
      category: GoalCategory.values.firstWhere(
        (e) => e.name == json['category'],
        orElse: () => GoalCategory.OTHER,
      ),
      color: json['color'] as String,
      isCompleted: json['isCompleted'] as bool,
      progressPercentage: (json['progressPercentage'] as num).toDouble(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'targetAmount': targetAmount,
      'currentAmount': currentAmount,
      if (targetDate != null) 'targetDate': targetDate!.toIso8601String(),
      'category': category.name,
      'color': color,
    };
  }
}
