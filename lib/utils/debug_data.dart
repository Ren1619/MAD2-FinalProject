import '../services/database_helper.dart';
import '../utils/uuid_generator.dart';
import '../services/auth_service.dart';
import 'package:intl/intl.dart';

class DebugData {
  static Future<void> populateDebugData() async {
    final DatabaseHelper dbHelper = DatabaseHelper();

    // Check if we already have data
    final users = await dbHelper.getUsers();
    if (users.length > 1) {
      print('Debug data already populated, skipping...');
      return;
    }

    // Create test company
    final String companyId = UuidGenerator.generateUuid();
    await dbHelper.insertCompany({
      'id': companyId,
      'name': 'Acme Corporation',
      'email': 'info@acmecorp.com',
      'phone': '+1 (555) 123-4567',
      'address': '123 Main Street',
      'city': 'New York',
      'state': 'NY',
      'zipcode': '10001',
      'website': 'www.acmecorp.com',
      'size': '51-200 employees',
      'industry': 'Information Technology',
      'createdAt': DateTime.now().toIso8601String(),
    });

    // Create test users with different roles
    final String companyAdminId = await _createUser(
      dbHelper,
      AuthService.ROLE_COMPANY_ADMIN, // Company Admin role
      'admin@acmecorp.com',
      companyId,
    );

    final String budgetManagerId = await _createUser(
      dbHelper,
      AuthService.ROLE_BUDGET_MANAGER,
      'budget@acmecorp.com',
      companyId,
    );

    final String financeManagerId = await _createUser(
      dbHelper,
      AuthService.ROLE_FINANCIAL_MANAGER,
      'finance@acmecorp.com',
      companyId,
    );

    final String spenderId = await _createUser(
      dbHelper,
      AuthService.ROLE_SPENDER,
      'spender@acmecorp.com',
      companyId,
    );

    // Inactive user
    await _createUser(
      dbHelper,
      AuthService.ROLE_SPENDER,
      'inactive@acmecorp.com',
      companyId,
      'Inactive',
    );

    // Create test budgets in different statuses
    final List<String> budgetIds = await _createBudgets(dbHelper, companyId);

    // Create test expenses for each budget
    if (budgetIds.isNotEmpty) {
      await _createExpenses(dbHelper, budgetIds, [
        budgetManagerId,
        financeManagerId,
        spenderId,
      ], companyId);
    }

    // Create some log entries
    await _createLogs(dbHelper, companyId);

    print('Debug data populated successfully');
  }

  // Helper to create a user
  static Future<String> _createUser(
    DatabaseHelper dbHelper,
    String role,
    String email,
    String companyId, [
    String status = 'Active',
  ]) async {
    final String userId = UuidGenerator.generateUuid();
    final String name = email.split('@')[0];
    final String capitalizedName = name[0].toUpperCase() + name.substring(1);

    await dbHelper.insertUser({
      'id': userId,
      'name': capitalizedName,
      'email': email,
      'role': role,
      'status': status,
      'createdAt': DateTime.now().toIso8601String(),
      'companyId': companyId,
      'phone':
          '+1 (555) ${_getRandomNumber(100, 999)}-${_getRandomNumber(1000, 9999)}',
      'enableNotifications': 1,
    });

    return userId;
  }

  // Helper to create budgets
  static Future<List<String>> _createBudgets(
    DatabaseHelper dbHelper,
    String companyId,
  ) async {
    final List<Map<String, dynamic>> users = await dbHelper.getUsersByCompany(
      companyId,
    );
    if (users.isEmpty) return [];

    final List<String> budgetIds = [];
    final List<String> statuses = [
      'Pending',
      'Approved',
      'For Revision',
      'Denied',
      'Archived',
    ];

    final List<String> budgetNames = [
      'Q1 Marketing Budget',
      'Software Development Resources',
      'Office Equipment Upgrade',
      'Employee Training Program',
      'Research & Development',
      'Trade Show Expenses',
      'Customer Support Enhancement',
      'IT Infrastructure',
      'Product Launch Campaign',
      'Year-end Conference',
    ];

    final List<String> descriptions = [
      'Budget for all marketing activities in Q1 including digital campaigns, print materials, and events.',
      'Resources needed for software development team including tools, licenses, and hardware.',
      'Upgrade of office equipment including computers, printers, and furniture.',
      'Training program for employees to enhance skills and knowledge.',
      'Budget for research and development activities for new product lines.',
      'Expenses for upcoming trade shows including booth, travel, and promotional materials.',
      'Enhancement of customer support systems and training for support staff.',
      'Upgrade and maintenance of IT infrastructure including servers and networking equipment.',
      'Comprehensive marketing campaign for new product launch.',
      'Budget for year-end conference including venue, speakers, and catering.',
    ];

    // Create 15 budgets with different statuses
    for (int i = 0; i < 15; i++) {
      final String budgetId = UuidGenerator.generateUuid();
      final String status = statuses[i % statuses.length];
      final int nameIndex = i % budgetNames.length;
      final int userIndex = i % users.length;
      final Map<String, dynamic> user = users[userIndex];

      // Base budget data
      final Map<String, dynamic> budgetData = {
        'id': budgetId,
        'name': budgetNames[nameIndex],
        'budget': _getRandomNumber(5000, 50000).toDouble(),
        'description': descriptions[nameIndex],
        'status': status,
        'dateSubmitted': _getRandomDate(60),
        'submittedBy': user['id'],
        'submittedByEmail': user['email'],
        'companyId': companyId,
      };

      // Add status-specific fields
      if (status == 'Approved') {
        budgetData['dateApproved'] = _getRandomDate(30);
      } else if (status == 'For Revision') {
        budgetData['revisionRequested'] = _getRandomDate(40);
        budgetData['revisionNotes'] =
            'Please provide more details on the budget allocation and expected ROI.';
      } else if (status == 'Denied') {
        budgetData['dateDenied'] = _getRandomDate(35);
        budgetData['denialReason'] =
            'Budget exceeds department allocation. Please revise and resubmit with reduced scope.';
      } else if (status == 'Archived') {
        budgetData['dateArchived'] = _getRandomDate(20);
      }

      await dbHelper.insertBudget(budgetData);
      budgetIds.add(budgetId);
    }

    return budgetIds;
  }

  // Helper to create expenses
  static Future<void> _createExpenses(
    DatabaseHelper dbHelper,
    List<String> budgetIds,
    List<String> userIds,
    String companyId,
  ) async {
    if (budgetIds.isEmpty || userIds.isEmpty) return;

    final List<String> statuses = ['Pending', 'Approved', 'Denied'];
    final List<String> categories = [
      'Supplies',
      'Meals',
      'Software',
      'Travel',
      'Events',
    ];
    final List<String> paymentMethods = [
      'Corporate Card',
      'Reimbursement',
      'Direct Invoice',
      'Cash',
    ];

    final List<String> descriptions = [
      'Office supplies purchase',
      'Team lunch meeting',
      'Software subscription renewal',
      'Client meeting transportation',
      'Conference registration fees',
      'Marketing materials printing',
      'Equipment purchase',
      'Training workshop fees',
      'Hotel accommodation for business trip',
      'Internet service bill',
      'Mobile device accessories',
      'Professional membership dues',
      'Client gifts',
      'Staff appreciation event',
      'Coworking space rental',
    ];

    // Create 30 expenses spread across budgets
    for (int i = 0; i < 30; i++) {
      final String expenseId = UuidGenerator.generateUuid();
      final String budgetId = budgetIds[i % budgetIds.length];
      final String userId = userIds[i % userIds.length];
      final String status = statuses[i % statuses.length];
      final String category = categories[i % categories.length];
      final String description = descriptions[i % descriptions.length];
      final String paymentMethod = paymentMethods[i % paymentMethods.length];
      final double amount = (_getRandomNumber(50, 2000) / 100) * 100;
      final bool hasReceipt = _getRandomNumber(0, 1) == 1;

      final Map<String, dynamic> expenseData = {
        'id': expenseId,
        'description': description,
        'amount': amount,
        'date': _getRandomDate(30, true),
        'category': category,
        'receipt': hasReceipt ? 1 : 0,
        'status': status,
        'paymentMethod': paymentMethod,
        'budgetId': budgetId,
        'userId': userId,
        'companyId': companyId,
      };

      // Add approver for approved expenses
      if (status == 'Approved') {
        // Use a different user as the approver
        final String approverId = userIds[(i + 1) % userIds.length];
        final Map<String, dynamic>? approver = await dbHelper.getUserById(
          approverId,
        );
        if (approver != null) {
          expenseData['approvedBy'] = approver['name'];
        }
      }

      await dbHelper.insertExpense(expenseData);
    }
  }

  // Helper to create logs
  static Future<void> _createLogs(
    DatabaseHelper dbHelper,
    String companyId,
  ) async {
    final List<Map<String, dynamic>> users = await dbHelper.getUsersByCompany(
      companyId,
    );
    if (users.isEmpty) return;

    final List<String> logTypes = [
      'Authentication',
      'Account Management',
      'Budget',
      'System',
    ];

    final List<String> authEvents = [
      'User logged in',
      'User logged out',
      'Failed login attempt',
      'Password reset requested',
      'Two-factor authentication enabled',
    ];

    final List<String> accountEvents = [
      'Account created',
      'Account updated',
      'Role changed',
      'Status changed to Inactive',
      'Password changed',
    ];

    final List<String> budgetEvents = [
      'Budget submitted',
      'Budget approved',
      'Budget revision requested',
      'Budget denied',
      'Budget archived',
    ];

    final List<String> systemEvents = [
      'System backup completed',
      'Database maintenance performed',
      'System update installed',
      'Config changes applied',
      'Security scan completed',
    ];

    // Create 50 log entries
    for (int i = 0; i < 50; i++) {
      final String logId = UuidGenerator.generateUuid();
      final String type = logTypes[i % logTypes.length];
      final int userIndex = i % users.length;
      final Map<String, dynamic> user = users[userIndex];

      String description;
      if (type == 'Authentication') {
        description = '${authEvents[i % authEvents.length]}: ${user['email']}';
      } else if (type == 'Account Management') {
        description =
            '${accountEvents[i % accountEvents.length]}: ${user['email']}';
      } else if (type == 'Budget') {
        description =
            '${budgetEvents[i % budgetEvents.length]} by ${user['name']}';
      } else {
        description = systemEvents[i % systemEvents.length];
      }

      await dbHelper.insertLog({
        'id': logId,
        'description': description,
        'timestamp': _getRandomDate(60, true),
        'type': type,
        'user': user['name'],
        'ip': '192.168.${_getRandomNumber(1, 255)}.${_getRandomNumber(1, 255)}',
        'companyId': companyId,
      });
    }
  }

  // Helper to get a random number in a range
  static int _getRandomNumber(int min, int max) {
    return min + (DateTime.now().microsecondsSinceEpoch % (max - min + 1));
  }

  // Helper to get a random date within the last X days
  static String _getRandomDate(int daysBack, [bool includeTime = false]) {
    final now = DateTime.now();
    final random = _getRandomNumber(1, daysBack);
    final date = now.subtract(Duration(days: random));

    if (includeTime) {
      // Add random hours and minutes
      final hours = _getRandomNumber(0, 23);
      final minutes = _getRandomNumber(0, 59);
      final dateWithTime = DateTime(
        date.year,
        date.month,
        date.day,
        hours,
        minutes,
      );
      return dateWithTime.toIso8601String();
    }

    // Date only
    return DateTime(date.year, date.month, date.day).toIso8601String();
  }
}
