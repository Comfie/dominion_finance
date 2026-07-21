class Person {
  final String id;
  final String name;
  final double? budgetLimit;
  final DateTime createdAt;

  Person({
    required this.id,
    required this.name,
    this.budgetLimit,
    required this.createdAt,
  });

  factory Person.fromJson(Map<String, dynamic> json) {
    return Person(
      id: json['id'] as String,
      name: json['name'] as String,
      budgetLimit: json['budgetLimit'] != null ? (json['budgetLimit'] as num).toDouble() : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      if (budgetLimit != null) 'budgetLimit': budgetLimit,
    };
  }
}
