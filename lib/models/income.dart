import '../core/constants.dart';

class Income {
  final String id;
  final String name;
  final double amount;
  final IncomeSource source;
  final DateTime date;
  final bool isRecurring;
  final String? notes;
  final DateTime createdAt;

  Income({
    required this.id,
    required this.name,
    required this.amount,
    required this.source,
    required this.date,
    required this.isRecurring,
    this.notes,
    required this.createdAt,
  });

  factory Income.fromJson(Map<String, dynamic> json) {
    return Income(
      id: json['id'] as String,
      name: json['name'] as String,
      amount: (json['amount'] as num).toDouble(),
      source: IncomeSource.values.firstWhere(
        (e) => e.name == json['source'],
        orElse: () => IncomeSource.OTHER,
      ),
      date: DateTime.parse(json['date'] as String),
      isRecurring: json['isRecurring'] as bool,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'amount': amount,
      'source': source.name,
      'date': date.toIso8601String(),
      'isRecurring': isRecurring,
      if (notes != null) 'notes': notes,
    };
  }
}
