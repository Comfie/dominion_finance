import '../core/constants.dart';

class Obligation {
  final String id;
  final String name;
  final String provider;
  final Category category;
  final double amount;
  final double? totalBalance;
  final double? interestRate;
  final int debitOrderDate;
  final bool isUncompromised;
  final bool isActive;
  final String? personId;
  final String? personName;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isPaidThisMonth;

  Obligation({
    required this.id,
    required this.name,
    required this.provider,
    required this.category,
    required this.amount,
    this.totalBalance,
    this.interestRate,
    required this.debitOrderDate,
    required this.isUncompromised,
    required this.isActive,
    this.personId,
    this.personName,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    required this.isPaidThisMonth,
  });

  factory Obligation.fromJson(Map<String, dynamic> json) {
    return Obligation(
      id: json['id'] as String,
      name: json['name'] as String,
      provider: json['provider'] as String,
      category: Category.values.firstWhere(
        (e) => e.name == json['category'],
        orElse: () => Category.OTHER,
      ),
      amount: (json['amount'] as num).toDouble(),
      totalBalance: json['totalBalance'] != null ? (json['totalBalance'] as num).toDouble() : null,
      interestRate: json['interestRate'] != null ? (json['interestRate'] as num).toDouble() : null,
      debitOrderDate: json['debitOrderDate'] as int,
      isUncompromised: json['isUncompromised'] as bool,
      isActive: json['isActive'] as bool,
      personId: json['personId'] as String?,
      personName: json['personName'] as String?,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      isPaidThisMonth: json['isPaidThisMonth'] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'provider': provider,
      'category': category.name,
      'amount': amount,
      if (totalBalance != null) 'totalBalance': totalBalance,
      if (interestRate != null) 'interestRate': interestRate,
      'debitOrderDate': debitOrderDate,
      'isUncompromised': isUncompromised,
      if (personId != null) 'personId': personId,
      if (notes != null) 'notes': notes,
    };
  }
}
