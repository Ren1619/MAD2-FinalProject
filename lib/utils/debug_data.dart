import '../services/database_helper.dart';
import '../utils/uuid_generator.dart';

class DebugData {
  static Future<void> populateDebugData() async {
    final DatabaseHelper dbHelper = DatabaseHelper();

    // Check if there are any users
    List<Map<String, dynamic>> existingUsers = await dbHelper.getUsers();

    if (existingUsers.isEmpty) {
      // Add a debug admin user
      String adminId = UuidGenerator.generateUuid();
      await dbHelper.insertUser({
        'id': adminId,
        'name': 'Admin User',
        'email': 'admin@example.com',
        'role': 'Budget Manager',
        'status': 'Active',
        'createdAt': DateTime.now().toIso8601String(),
      });

      // Add additional user roles for testing
      String fpManagerId = UuidGenerator.generateUuid();
      await dbHelper.insertUser({
        'id': fpManagerId,
        'name': 'Finance Manager',
        'email': 'finance@example.com',
        'role': 'Financial Planning and Analysis Manager',
        'status': 'Active',
        'createdAt': DateTime.now().toIso8601String(),
      });

      String userId = UuidGenerator.generateUuid();
      await dbHelper.insertUser({
        'id': userId,
        'name': 'John Doe',
        'email': 'user@example.com',
        'role': 'Authorized Spender',
        'status': 'Active',
        'createdAt': DateTime.now().toIso8601String(),
      });

      String inactiveId = UuidGenerator.generateUuid();
      await dbHelper.insertUser({
        'id': inactiveId,
        'name': 'Jane Smith',
        'email': 'inactive@example.com',
        'role': 'Authorized Spender',
        'status': 'Inactive',
        'createdAt':
            DateTime.now().subtract(const Duration(days: 30)).toIso8601String(),
      });

      // Add sample budgets with different statuses
      String budget1Id = UuidGenerator.generateUuid();
      await dbHelper.insertBudget({
        'id': budget1Id,
        'name': 'Q1 Marketing Campaign',
        'budget': 25000.00,
        'description':
            'Budget for Q1 digital marketing initiatives across all platforms',
        'status': 'Pending',
        'dateSubmitted':
            DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
        'submittedBy': userId,
        'submittedByEmail': 'user@example.com',
      });

      String budget2Id = UuidGenerator.generateUuid();
      await dbHelper.insertBudget({
        'id': budget2Id,
        'name': 'IT Infrastructure Upgrade',
        'budget': 75000.00,
        'description': 'Server upgrades and new developer workstations',
        'status': 'Approved',
        'dateSubmitted':
            DateTime.now().subtract(const Duration(days: 15)).toIso8601String(),
        'dateApproved':
            DateTime.now().subtract(const Duration(days: 8)).toIso8601String(),
        'submittedBy': userId,
        'submittedByEmail': 'user@example.com',
      });

      String budget3Id = UuidGenerator.generateUuid();
      await dbHelper.insertBudget({
        'id': budget3Id,
        'name': 'Office Renovation Project',
        'budget': 120000.00,
        'description':
            'Renovation of main office space including furniture and fixtures',
        'status': 'For Revision',
        'dateSubmitted':
            DateTime.now().subtract(const Duration(days: 10)).toIso8601String(),
        'revisionRequested':
            DateTime.now().subtract(const Duration(days: 5)).toIso8601String(),
        'revisionNotes':
            'Please provide a detailed breakdown of renovation costs by category.',
        'submittedBy': fpManagerId,
        'submittedByEmail': 'finance@example.com',
      });

      String budget4Id = UuidGenerator.generateUuid();
      await dbHelper.insertBudget({
        'id': budget4Id,
        'name': 'Annual Team Building Event',
        'budget': 15000.00,
        'description': 'Annual team-building retreat for all departments',
        'status': 'Denied',
        'dateSubmitted':
            DateTime.now().subtract(const Duration(days: 20)).toIso8601String(),
        'dateDenied':
            DateTime.now().subtract(const Duration(days: 18)).toIso8601String(),
        'denialReason':
            'Budget exceeded department allocation. Please reduce by 30% or provide additional justification.',
        'submittedBy': userId,
        'submittedByEmail': 'user@example.com',
      });

      String budget5Id = UuidGenerator.generateUuid();
      await dbHelper.insertBudget({
        'id': budget5Id,
        'name': 'Q4 2023 Marketing Campaign',
        'budget': 30000.00,
        'description': 'End of year marketing initiatives for product launch',
        'status': 'Archived',
        'dateSubmitted':
            DateTime.now()
                .subtract(const Duration(days: 120))
                .toIso8601String(),
        'dateApproved':
            DateTime.now()
                .subtract(const Duration(days: 115))
                .toIso8601String(),
        'dateArchived':
            DateTime.now().subtract(const Duration(days: 30)).toIso8601String(),
        'submittedBy': adminId,
        'submittedByEmail': 'admin@example.com',
      });

      // Add sample logs
      await dbHelper.insertLog({
        'id': UuidGenerator.generateUuid(),
        'description': 'System initialized',
        'timestamp':
            DateTime.now().subtract(const Duration(days: 30)).toIso8601String(),
        'type': 'System',
        'user': 'System',
        'ip': '127.0.0.1',
      });

      await dbHelper.insertLog({
        'id': UuidGenerator.generateUuid(),
        'description': 'User login: admin@example.com',
        'timestamp':
            DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
        'type': 'Authentication',
        'user': 'Admin User',
        'ip': '127.0.0.1',
      });

      await dbHelper.insertLog({
        'id': UuidGenerator.generateUuid(),
        'description': 'Budget approved: IT Infrastructure Upgrade',
        'timestamp':
            DateTime.now().subtract(const Duration(days: 8)).toIso8601String(),
        'type': 'Budget',
        'user': 'Admin User',
        'ip': '127.0.0.1',
      });

      await dbHelper.insertLog({
        'id': UuidGenerator.generateUuid(),
        'description': 'New account created: finance@example.com',
        'timestamp':
            DateTime.now().subtract(const Duration(days: 25)).toIso8601String(),
        'type': 'Account Management',
        'user': 'Admin User',
        'ip': '127.0.0.1',
      });

      await dbHelper.insertLog({
        'id': UuidGenerator.generateUuid(),
        'description':
            'User status changed: inactive@example.com set to Inactive',
        'timestamp':
            DateTime.now().subtract(const Duration(days: 15)).toIso8601String(),
        'type': 'Account Management',
        'user': 'Admin User',
        'ip': '127.0.0.1',
      });
    }
  }
}
