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
      
      // Add a regular user
      String userId = UuidGenerator.generateUuid();
      await dbHelper.insertUser({
        'id': userId,
        'name': 'John Doe',
        'email': 'user@example.com',
        'role': 'Authorized Spender',
        'status': 'Active',
        'createdAt': DateTime.now().toIso8601String(),
      });
      
      // Add some sample budgets
      String budget1Id = UuidGenerator.generateUuid();
      await dbHelper.insertBudget({
        'id': budget1Id,
        'name': 'Q1 Marketing Campaign',
        'budget': 25000.00,
        'description': 'Budget for Q1 digital marketing initiatives across all platforms',
        'status': 'Pending',
        'dateSubmitted': DateTime.now().subtract(Duration(days: 2)).toIso8601String(),
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
        'dateSubmitted': DateTime.now().subtract(Duration(days: 15)).toIso8601String(),
        'dateApproved': DateTime.now().subtract(Duration(days: 8)).toIso8601String(),
        'submittedBy': userId,
        'submittedByEmail': 'user@example.com',
      });
      
      // Add sample logs
      await dbHelper.insertLog({
        'id': UuidGenerator.generateUuid(),
        'description': 'System initialized',
        'timestamp': DateTime.now().toIso8601String(),
        'type': 'System',
        'user': 'System',
        'ip': '127.0.0.1',
      });
    }
  }
}