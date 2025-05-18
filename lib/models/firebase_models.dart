import 'package:cloud_firestore/cloud_firestore.dart';

// Company Model
class Company {
  final String companyId;
  final String companyName;
  final String email;
  final String phone;
  final String address;
  final String city;
  final String state;
  final String zipcode;
  final String website;
  final String size;
  final String industry;
  final DateTime createdAt;

  Company({
    required this.companyId,
    required this.companyName,
    required this.email,
    this.phone = '',
    this.address = '',
    this.city = '',
    this.state = '',
    this.zipcode = '',
    this.website = '',
    this.size = '1-10 employees',
    this.industry = 'Information Technology',
    required this.createdAt,
  });

  // Convert to Map for Firebase
  Map<String, dynamic> toFirestore() {
    return {
      'company_id': companyId,
      'company_name': companyName,
      'email': email,
      'phone': phone,
      'address': address,
      'city': city,
      'state': state,
      'zipcode': zipcode,
      'website': website,
      'size': size,
      'industry': industry,
      'created_at': Timestamp.fromDate(createdAt),
    };
  }

  // Create from Firebase document
  factory Company.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Company(
      companyId: data['company_id'] ?? doc.id,
      companyName: data['company_name'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      address: data['address'] ?? '',
      city: data['city'] ?? '',
      state: data['state'] ?? '',
      zipcode: data['zipcode'] ?? '',
      website: data['website'] ?? '',
      size: data['size'] ?? '1-10 employees',
      industry: data['industry'] ?? 'Information Technology',
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // Create from Map
  factory Company.fromMap(Map<String, dynamic> map) {
    return Company(
      companyId: map['company_id'] ?? '',
      companyName: map['company_name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      address: map['address'] ?? '',
      city: map['city'] ?? '',
      state: map['state'] ?? '',
      zipcode: map['zipcode'] ?? '',
      website: map['website'] ?? '',
      size: map['size'] ?? '1-10 employees',
      industry: map['industry'] ?? 'Information Technology',
      createdAt:
          map['created_at'] is Timestamp
              ? (map['created_at'] as Timestamp).toDate()
              : DateTime.tryParse(map['created_at'] ?? '') ?? DateTime.now(),
    );
  }

  // Get formatted address
  String get formattedAddress {
    List<String> parts = [];
    if (address.isNotEmpty) parts.add(address);

    String cityStateZip = '';
    if (city.isNotEmpty) cityStateZip += city;
    if (state.isNotEmpty)
      cityStateZip += cityStateZip.isNotEmpty ? ', $state' : state;
    if (zipcode.isNotEmpty)
      cityStateZip += cityStateZip.isNotEmpty ? ' $zipcode' : zipcode;

    if (cityStateZip.isNotEmpty) parts.add(cityStateZip);
    return parts.join('\n');
  }

  // Validation
  String? validate() {
    if (companyName.trim().isEmpty) return 'Company name is required';
    if (email.trim().isEmpty) return 'Email is required';
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      return 'Invalid email format';
    }
    return null;
  }

  // Copy with modifications
  Company copyWith({
    String? companyId,
    String? companyName,
    String? email,
    String? phone,
    String? address,
    String? city,
    String? state,
    String? zipcode,
    String? website,
    String? size,
    String? industry,
    DateTime? createdAt,
  }) {
    return Company(
      companyId: companyId ?? this.companyId,
      companyName: companyName ?? this.companyName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      city: city ?? this.city,
      state: state ?? this.state,
      zipcode: zipcode ?? this.zipcode,
      website: website ?? this.website,
      size: size ?? this.size,
      industry: industry ?? this.industry,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

// Account Model
class Account {
  final String accountId;
  final String companyId;
  final String firstName;
  final String lastName;
  final String email;
  final String contactNumber;
  final String role;
  final String status;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Account({
    required this.accountId,
    required this.companyId,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.contactNumber = '',
    required this.role,
    this.status = 'Active',
    required this.createdAt,
    this.updatedAt,
  });

  // Convert to Map for Firebase
  Map<String, dynamic> toFirestore() {
    return {
      'account_id': accountId,
      'company_id': companyId,
      'f_name': firstName,
      'l_name': lastName,
      'email': email,
      'contact_number': contactNumber,
      'role': role,
      'status': status,
      'created_at': Timestamp.fromDate(createdAt),
      if (updatedAt != null) 'updated_at': Timestamp.fromDate(updatedAt!),
    };
  }

  // Create from Firebase document
  factory Account.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Account(
      accountId: data['account_id'] ?? doc.id,
      companyId: data['company_id'] ?? '',
      firstName: data['f_name'] ?? '',
      lastName: data['l_name'] ?? '',
      email: data['email'] ?? '',
      contactNumber: data['contact_number'] ?? '',
      role: data['role'] ?? '',
      status: data['status'] ?? 'Active',
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updated_at'] as Timestamp?)?.toDate(),
    );
  }

  // Create from Map
  factory Account.fromMap(Map<String, dynamic> map) {
    return Account(
      accountId: map['account_id'] ?? map['id'] ?? '',
      companyId: map['company_id'] ?? '',
      firstName: map['f_name'] ?? map['firstName'] ?? '',
      lastName: map['l_name'] ?? map['lastName'] ?? '',
      email: map['email'] ?? '',
      contactNumber: map['contact_number'] ?? map['phone'] ?? '',
      role: map['role'] ?? '',
      status: map['status'] ?? 'Active',
      createdAt:
          map['created_at'] is Timestamp
              ? (map['created_at'] as Timestamp).toDate()
              : DateTime.tryParse(map['created_at'] ?? '') ?? DateTime.now(),
      updatedAt:
          map['updated_at'] is Timestamp
              ? (map['updated_at'] as Timestamp).toDate()
              : (map['updated_at'] != null
                  ? DateTime.tryParse(map['updated_at'])
                  : null),
    );
  }

  // Get full name
  String get fullName => '$firstName $lastName'.trim();

  // Get initials
  String get initials {
    String f = firstName.isNotEmpty ? firstName[0].toUpperCase() : '';
    String l = lastName.isNotEmpty ? lastName[0].toUpperCase() : '';
    return '$f$l';
  }

  // Check if admin
  bool get isAdmin => role == 'Administrator';

  // Check if active
  bool get isActive => status == 'Active';

  // Validation
  String? validate() {
    if (firstName.trim().isEmpty) return 'First name is required';
    if (lastName.trim().isEmpty) return 'Last name is required';
    if (email.trim().isEmpty) return 'Email is required';
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      return 'Invalid email format';
    }
    if (role.trim().isEmpty) return 'Role is required';
    return null;
  }

  // Copy with modifications
  Account copyWith({
    String? accountId,
    String? companyId,
    String? firstName,
    String? lastName,
    String? email,
    String? contactNumber,
    String? role,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Account(
      accountId: accountId ?? this.accountId,
      companyId: companyId ?? this.companyId,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      contactNumber: contactNumber ?? this.contactNumber,
      role: role ?? this.role,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

// Budget Model
class Budget {
  final String budgetId;
  final String budgetName;
  final double budgetAmount;
  final String budgetDescription;
  final String status;
  final String createdBy;
  final String companyId;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? updatedBy;
  final String? notes;

  // Additional fields for UI
  final String? createdByName;
  final String? createdByEmail;
  final List<Account>? authorizedSpenders;
  final double? totalExpenses;
  final int? expenseCount;

  Budget({
    required this.budgetId,
    required this.budgetName,
    required this.budgetAmount,
    required this.budgetDescription,
    this.status = 'Pending for Approval',
    required this.createdBy,
    required this.companyId,
    required this.createdAt,
    this.updatedAt,
    this.updatedBy,
    this.notes,
    this.createdByName,
    this.createdByEmail,
    this.authorizedSpenders,
    this.totalExpenses,
    this.expenseCount,
  });

  // Convert to Map for Firebase
  Map<String, dynamic> toFirestore() {
    return {
      'budget_id': budgetId,
      'budget_name': budgetName,
      'budget_amount': budgetAmount,
      'budget_description': budgetDescription,
      'status': status,
      'created_by': createdBy,
      'company_id': companyId,
      'created_at': Timestamp.fromDate(createdAt),
      if (updatedAt != null) 'updated_at': Timestamp.fromDate(updatedAt!),
      if (updatedBy != null) 'updated_by': updatedBy,
      if (notes != null) 'notes': notes,
    };
  }

  // Create from Firebase document
  factory Budget.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Budget(
      budgetId: data['budget_id'] ?? doc.id,
      budgetName: data['budget_name'] ?? '',
      budgetAmount: (data['budget_amount'] as num?)?.toDouble() ?? 0.0,
      budgetDescription: data['budget_description'] ?? '',
      status: data['status'] ?? 'Pending for Approval',
      createdBy: data['created_by'] ?? '',
      companyId: data['company_id'] ?? '',
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updated_at'] as Timestamp?)?.toDate(),
      updatedBy: data['updated_by'],
      notes: data['notes'],
    );
  }

  // Create from Map (with additional fields)
  factory Budget.fromMap(Map<String, dynamic> map) {
    return Budget(
      budgetId: map['budget_id'] ?? map['id'] ?? '',
      budgetName: map['budget_name'] ?? map['name'] ?? '',
      budgetAmount: (map['budget_amount'] ?? map['budget'] ?? 0.0).toDouble(),
      budgetDescription: map['budget_description'] ?? map['description'] ?? '',
      status: map['status'] ?? 'Pending for Approval',
      createdBy: map['created_by'] ?? '',
      companyId: map['company_id'] ?? '',
      createdAt:
          map['created_at'] is Timestamp
              ? (map['created_at'] as Timestamp).toDate()
              : DateTime.tryParse(map['created_at'] ?? '') ?? DateTime.now(),
      updatedAt:
          map['updated_at'] is Timestamp
              ? (map['updated_at'] as Timestamp).toDate()
              : (map['updated_at'] != null
                  ? DateTime.tryParse(map['updated_at'])
                  : null),
      updatedBy: map['updated_by'],
      notes: map['notes'],
      createdByName: map['created_by_name'],
      createdByEmail: map['created_by_email'],
      totalExpenses: (map['total_expenses'] as num?)?.toDouble(),
      expenseCount: map['expense_count'],
    );
  }

  // Get remaining amount
  double get remainingAmount => budgetAmount - (totalExpenses ?? 0.0);

  // Get percentage used
  double get percentageUsed =>
      budgetAmount > 0 ? (totalExpenses ?? 0.0) / budgetAmount : 0.0;

  // Check if over budget
  bool get isOverBudget => (totalExpenses ?? 0.0) > budgetAmount;

  // Check if pending approval
  bool get isPending => status == 'Pending for Approval';

  // Check if active
  bool get isActive => status == 'Active';

  // Format currency
  String get formattedAmount => '\$${budgetAmount.toStringAsFixed(2)}';
  String get formattedExpenses =>
      '\$${(totalExpenses ?? 0.0).toStringAsFixed(2)}';
  String get formattedRemaining => '\$${remainingAmount.toStringAsFixed(2)}';

  // Validation
  String? validate() {
    if (budgetName.trim().isEmpty) return 'Budget name is required';
    if (budgetAmount <= 0) return 'Budget amount must be greater than zero';
    if (budgetDescription.trim().isEmpty)
      return 'Budget description is required';
    return null;
  }

  // Copy with modifications
  Budget copyWith({
    String? budgetId,
    String? budgetName,
    double? budgetAmount,
    String? budgetDescription,
    String? status,
    String? createdBy,
    String? companyId,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? updatedBy,
    String? notes,
    String? createdByName,
    String? createdByEmail,
    List<Account>? authorizedSpenders,
    double? totalExpenses,
    int? expenseCount,
  }) {
    return Budget(
      budgetId: budgetId ?? this.budgetId,
      budgetName: budgetName ?? this.budgetName,
      budgetAmount: budgetAmount ?? this.budgetAmount,
      budgetDescription: budgetDescription ?? this.budgetDescription,
      status: status ?? this.status,
      createdBy: createdBy ?? this.createdBy,
      companyId: companyId ?? this.companyId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
      notes: notes ?? this.notes,
      createdByName: createdByName ?? this.createdByName,
      createdByEmail: createdByEmail ?? this.createdByEmail,
      authorizedSpenders: authorizedSpenders ?? this.authorizedSpenders,
      totalExpenses: totalExpenses ?? this.totalExpenses,
      expenseCount: expenseCount ?? this.expenseCount,
    );
  }
}

// Budget Authorized Spender Model
class BudgetAuthorizedSpender {
  final String budgetAuthId;
  final String budgetId;
  final String accountId;
  final DateTime createdAt;

  BudgetAuthorizedSpender({
    required this.budgetAuthId,
    required this.budgetId,
    required this.accountId,
    required this.createdAt,
  });

  // Convert to Map for Firebase
  Map<String, dynamic> toFirestore() {
    return {
      'budget_auth_id': budgetAuthId,
      'budget_id': budgetId,
      'account_id': accountId,
      'created_at': Timestamp.fromDate(createdAt),
    };
  }

  // Create from Firebase document
  factory BudgetAuthorizedSpender.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BudgetAuthorizedSpender(
      budgetAuthId: data['budget_auth_id'] ?? doc.id,
      budgetId: data['budget_id'] ?? '',
      accountId: data['account_id'] ?? '',
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // Create from Map
  factory BudgetAuthorizedSpender.fromMap(Map<String, dynamic> map) {
    return BudgetAuthorizedSpender(
      budgetAuthId: map['budget_auth_id'] ?? '',
      budgetId: map['budget_id'] ?? '',
      accountId: map['account_id'] ?? '',
      createdAt:
          map['created_at'] is Timestamp
              ? (map['created_at'] as Timestamp).toDate()
              : DateTime.tryParse(map['created_at'] ?? '') ?? DateTime.now(),
    );
  }
}

// Expense Model
class Expense {
  final String expenseId;
  final String budgetAuthId;
  final String budgetId;
  final String expenseDescription;
  final double expenseAmount;
  final String status;
  final String createdBy;
  final String companyId;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? updatedBy;
  final String? notes;
  final String? receiptImage; // Base64 string
  final bool hasReceipt;

  // Additional fields for UI
  final String? createdByName;
  final String? createdByEmail;
  final String? budgetName;

  Expense({
    required this.expenseId,
    required this.budgetAuthId,
    required this.budgetId,
    required this.expenseDescription,
    required this.expenseAmount,
    this.status = 'Pending',
    required this.createdBy,
    required this.companyId,
    required this.createdAt,
    this.updatedAt,
    this.updatedBy,
    this.notes,
    this.receiptImage,
    this.hasReceipt = false,
    this.createdByName,
    this.createdByEmail,
    this.budgetName,
  });

  // Convert to Map for Firebase
  Map<String, dynamic> toFirestore() {
    return {
      'expense_id': expenseId,
      'budget_auth_id': budgetAuthId,
      'budget_id': budgetId,
      'expense_desc': expenseDescription,
      'expense_amt': expenseAmount,
      'status': status,
      'created_by': createdBy,
      'company_id': companyId,
      'created_at': Timestamp.fromDate(createdAt),
      if (updatedAt != null) 'updated_at': Timestamp.fromDate(updatedAt!),
      if (updatedBy != null) 'updated_by': updatedBy,
      if (notes != null) 'notes': notes,
      if (receiptImage != null) 'receipt_image': receiptImage,
      'has_receipt': hasReceipt,
    };
  }

  // Create from Firebase document
  factory Expense.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Expense(
      expenseId: data['expense_id'] ?? doc.id,
      budgetAuthId: data['budget_auth_id'] ?? '',
      budgetId: data['budget_id'] ?? '',
      expenseDescription: data['expense_desc'] ?? '',
      expenseAmount: (data['expense_amt'] as num?)?.toDouble() ?? 0.0,
      status: data['status'] ?? 'Pending',
      createdBy: data['created_by'] ?? '',
      companyId: data['company_id'] ?? '',
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updated_at'] as Timestamp?)?.toDate(),
      updatedBy: data['updated_by'],
      notes: data['notes'],
      receiptImage: data['receipt_image'],
      hasReceipt: data['has_receipt'] ?? false,
    );
  }

  // Create from Map (with additional fields)
  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      expenseId: map['expense_id'] ?? map['id'] ?? '',
      budgetAuthId: map['budget_auth_id'] ?? '',
      budgetId: map['budget_id'] ?? '',
      expenseDescription: map['expense_desc'] ?? map['description'] ?? '',
      expenseAmount: (map['expense_amt'] ?? map['amount'] ?? 0.0).toDouble(),
      status: map['status'] ?? 'Pending',
      createdBy: map['created_by'] ?? '',
      companyId: map['company_id'] ?? '',
      createdAt:
          map['created_at'] is Timestamp
              ? (map['created_at'] as Timestamp).toDate()
              : DateTime.tryParse(map['created_at'] ?? '') ?? DateTime.now(),
      updatedAt:
          map['updated_at'] is Timestamp
              ? (map['updated_at'] as Timestamp).toDate()
              : (map['updated_at'] != null
                  ? DateTime.tryParse(map['updated_at'])
                  : null),
      updatedBy: map['updated_by'],
      notes: map['notes'],
      receiptImage: map['receipt_image'],
      hasReceipt: map['has_receipt'] ?? false,
      createdByName: map['created_by_name'],
      createdByEmail: map['created_by_email'],
      budgetName: map['budget_name'],
    );
  }

  // Check if pending
  bool get isPending => status == 'Pending';

  // Check if approved
  bool get isApproved => status == 'Approved';

  // Check if fraudulent
  bool get isFraudulent => status == 'Fraudulent';

  // Format currency
  String get formattedAmount => '\$${expenseAmount.toStringAsFixed(2)}';

  // Get status color
  String get statusColor {
    switch (status) {
      case 'Approved':
        return 'green';
      case 'Pending':
        return 'orange';
      case 'Fraudulent':
        return 'red';
      default:
        return 'grey';
    }
  }

  // Validation
  String? validate() {
    if (expenseDescription.trim().isEmpty)
      return 'Expense description is required';
    if (expenseAmount <= 0) return 'Expense amount must be greater than zero';
    return null;
  }

  // Copy with modifications
  Expense copyWith({
    String? expenseId,
    String? budgetAuthId,
    String? budgetId,
    String? expenseDescription,
    double? expenseAmount,
    String? status,
    String? createdBy,
    String? companyId,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? updatedBy,
    String? notes,
    String? receiptImage,
    bool? hasReceipt,
    String? createdByName,
    String? createdByEmail,
    String? budgetName,
  }) {
    return Expense(
      expenseId: expenseId ?? this.expenseId,
      budgetAuthId: budgetAuthId ?? this.budgetAuthId,
      budgetId: budgetId ?? this.budgetId,
      expenseDescription: expenseDescription ?? this.expenseDescription,
      expenseAmount: expenseAmount ?? this.expenseAmount,
      status: status ?? this.status,
      createdBy: createdBy ?? this.createdBy,
      companyId: companyId ?? this.companyId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
      notes: notes ?? this.notes,
      receiptImage: receiptImage ?? this.receiptImage,
      hasReceipt: hasReceipt ?? this.hasReceipt,
      createdByName: createdByName ?? this.createdByName,
      createdByEmail: createdByEmail ?? this.createdByEmail,
      budgetName: budgetName ?? this.budgetName,
    );
  }
}

// Activity Log Model
class ActivityLog {
  final String logId;
  final String logDescription;
  final String type;
  final String? companyId;
  final String? userId;
  final DateTime createdAt;

  // Additional fields for UI
  final String? userName;
  final String? userEmail;
  final String? userRole;

  ActivityLog({
    required this.logId,
    required this.logDescription,
    required this.type,
    this.companyId,
    this.userId,
    required this.createdAt,
    this.userName,
    this.userEmail,
    this.userRole,
  });

  // Convert to Map for Firebase
  Map<String, dynamic> toFirestore() {
    return {
      'log_id': logId,
      'log_desc': logDescription,
      'type': type,
      if (companyId != null) 'company_id': companyId,
      if (userId != null) 'user_id': userId,
      'created_at': Timestamp.fromDate(createdAt),
    };
  }

  // Create from Firebase document
  factory ActivityLog.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ActivityLog(
      logId: data['log_id'] ?? doc.id,
      logDescription: data['log_desc'] ?? '',
      type: data['type'] ?? '',
      companyId: data['company_id'],
      userId: data['user_id'],
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // Create from Map (with additional fields)
  factory ActivityLog.fromMap(Map<String, dynamic> map) {
    return ActivityLog(
      logId: map['log_id'] ?? map['id'] ?? '',
      logDescription: map['log_desc'] ?? map['description'] ?? '',
      type: map['type'] ?? '',
      companyId: map['company_id'],
      userId: map['user_id'],
      createdAt:
          map['created_at'] is Timestamp
              ? (map['created_at'] as Timestamp).toDate()
              : DateTime.tryParse(map['created_at'] ?? '') ?? DateTime.now(),
      userName: map['user_name'],
      userEmail: map['user_email'],
      userRole: map['user_role'],
    );
  }

  // Format timestamp for display
  String get formattedTimestamp {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  // Get full formatted timestamp
  String get fullFormattedTimestamp {
    return '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')} '
        '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';
  }

  // Copy with modifications
  ActivityLog copyWith({
    String? logId,
    String? logDescription,
    String? type,
    String? companyId,
    String? userId,
    DateTime? createdAt,
    String? userName,
    String? userEmail,
    String? userRole,
  }) {
    return ActivityLog(
      logId: logId ?? this.logId,
      logDescription: logDescription ?? this.logDescription,
      type: type ?? this.type,
      companyId: companyId ?? this.companyId,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
      userRole: userRole ?? this.userRole,
    );
  }
}

// Enum constants
class BudgetStatus {
  static const String pending = 'Pending for Approval';
  static const String active = 'Active';
  static const String completed = 'Completed';
  static const String forRevision = 'For Revision';
}

class ExpenseStatus {
  static const String pending = 'Pending';
  static const String approved = 'Approved';
  static const String fraudulent = 'Fraudulent';
}

class AccountStatus {
  static const String active = 'Active';
  static const String inactive = 'Inactive';
}

class UserRoles {
  static const String administrator = 'Administrator';
  static const String budgetManager = 'Budget Manager';
  static const String financialOfficer =
      'Financial Planning and Budgeting Officer';
  static const String authorizedSpender = 'Authorized Spender';

  static List<String> get allRoles => [
    administrator,
    budgetManager,
    financialOfficer,
    authorizedSpender,
  ];

  static List<String> get nonAdminRoles => [
    budgetManager,
    financialOfficer,
    authorizedSpender,
  ];
}

class LogTypes {
  static const String authentication = 'Authentication';
  static const String accountManagement = 'Account Management';
  static const String budgetManagement = 'Budget Management';
  static const String expenseManagement = 'Expense Management';
  static const String system = 'System';

  static List<String> get allTypes => [
    authentication,
    accountManagement,
    budgetManagement,
    expenseManagement,
    system,
  ];
}
