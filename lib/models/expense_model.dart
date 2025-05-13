class Expense {
  final String id;
  final String description;
  final double amount;
  final DateTime date;
  final String category;
  final String? approvedBy;
  final bool receipt;
  final String status;
  final String paymentMethod;
  final String? budgetId;
  final String? userId;
  final String? companyId;

  Expense({
    required this.id,
    required this.description,
    required this.amount,
    required this.date,
    required this.category,
    this.approvedBy,
    required this.receipt,
    required this.status,
    required this.paymentMethod,
    this.budgetId,
    this.userId,
    this.companyId,
  });

  // Convert an Expense object into a Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'description': description,
      'amount': amount,
      'date': date.toIso8601String(),
      'category': category,
      'approvedBy': approvedBy,
      'receipt': receipt ? 1 : 0,
      'status': status,
      'paymentMethod': paymentMethod,
      'budgetId': budgetId,
      'userId': userId,
      'companyId': companyId,
    };
  }

  // Create an Expense object from a Map
  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'] ?? '',
      description: map['description'] ?? '',
      amount: map['amount'] is int
          ? (map['amount'] as int).toDouble()
          : (map['amount'] as num?)?.toDouble() ?? 0.0,
      date: map['date'] is String 
          ? DateTime.parse(map['date']) 
          : (map['date'] as DateTime? ?? DateTime.now()),
      category: map['category'] ?? '',
      approvedBy: map['approvedBy'],
      receipt: map['receipt'] == 1,
      status: map['status'] ?? '',
      paymentMethod: map['paymentMethod'] ?? '',
      budgetId: map['budgetId'],
      userId: map['userId'],
      companyId: map['companyId'],
    );
  }
}