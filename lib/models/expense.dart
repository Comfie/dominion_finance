import '../core/constants.dart';

class Expense {
  final String id;
  final String name;
  final double amount;
  final Category category;
  final DateTime date;
  final String? personId;
  final String? personName;
  final String? notes;
  final DateTime createdAt;

  Expense({
    required this.id,
    required this.name,
    required this.amount,
    required this.category,
    required this.date,
    this.personId,
    this.personName,
    this.notes,
    required this.createdAt,
  });

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id'] as String,
      name: json['name'] as String,
      amount: (json['amount'] as num).toDouble(),
      category: Category.values.firstWhere(
        (e) => e.name == json['category'],
        orElse: () => Category.OTHER,
      ),
      date: DateTime.parse(json['date'] as String),
      personId: json['personId'] as String?,
      personName: json['personName'] as String?,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'amount': amount,
      'category': category.name,
      'date': date.toIso8601String(),
      if (personId != null) 'personId': personId,
      if (notes != null) 'notes': notes,
    };
  }
}
