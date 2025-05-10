import 'package:shared_preferences/shared_preferences.dart';
import '../utils/uuid_generator.dart';
import 'database_helper.dart';
import 'auth_service.dart';

class DatabaseService {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final AuthService _authService = AuthService();

  // Budget methods
  Future<List<Map<String, dynamic>>> fetchBudgets() async {
    try {
      return await _dbHelper.getBudgets();
    } catch (e) {
      print('Error fetching budgets: $e');
      return [];
    }
  }

  Future<bool> createBudget(Map<String, dynamic> budgetData) async {
    try {
      // Get current user
      Map<String, dynamic>? currentUser = await _authService.currentUser;

      // Add additional budget data
      String id = UuidGenerator.generateUuid();
      Map<String, dynamic> newBudget = {
        'id': id,
        ...budgetData,
        'dateSubmitted': DateTime.now().toIso8601String(),
        'status': 'Pending',
        'submittedBy': currentUser?['id'],
        'submittedByEmail': currentUser?['email'],
      };

      await _dbHelper.insertBudget(newBudget);

      // Log activity
      await logActivity(
        'New budget submitted: ${budgetData['name']}',
        'Budget',
      );

      return true;
    } catch (e) {
      print('Error creating budget: $e');
      return false;
    }
  }

  Future<bool> updateBudgetStatus(
    String budgetId,
    String newStatus, {
    String? notes,
  }) async {
    try {
      // Get budget
      Map<String, dynamic>? budget = await _dbHelper.getBudgetById(budgetId);

      if (budget == null) {
        return false;
      }

      // Create update data
      Map<String, dynamic> updateData = {'status': newStatus};

      // Add appropriate timestamp field based on status
      if (newStatus == 'Approved') {
        updateData['dateApproved'] = DateTime.now().toIso8601String();
      } else if (newStatus == 'Denied') {
        updateData['dateDenied'] = DateTime.now().toIso8601String();
        if (notes != null) updateData['denialReason'] = notes;
      } else if (newStatus == 'For Revision') {
        updateData['revisionRequested'] = DateTime.now().toIso8601String();
        if (notes != null) updateData['revisionNotes'] = notes;
      } else if (newStatus == 'Archived') {
        updateData['dateArchived'] = DateTime.now().toIso8601String();
      }

      await _dbHelper.updateBudgetStatus(budgetId, updateData);

      // Log activity
      String description =
          'Budget status updated to $newStatus: ${budget['name']}';
      await logActivity(description, 'Budget');

      return true;
    } catch (e) {
      print('Error updating budget status: $e');
      return false;
    }
  }

  // User account methods
  Future<List<Map<String, dynamic>>> fetchUsers() async {
    try {
      return await _dbHelper.getUsers();
    } catch (e) {
      print('Error fetching users: $e');
      return [];
    }
  }

  Future<bool> updateUserStatus(String userId, String newStatus) async {
    try {
      await _dbHelper.updateUserStatus(userId, newStatus);

      // Log activity
      String description = 'User status updated to $newStatus';
      await logActivity(description, 'Account Management');

      return true;
    } catch (e) {
      print('Error updating user status: $e');
      return false;
    }
  }

  // Logging methods
  Future<List<Map<String, dynamic>>> fetchLogs() async {
    try {
      return await _dbHelper.getLogs();
    } catch (e) {
      print('Error fetching logs: $e');
      return [];
    }
  }

  Future<void> logActivity(String description, String type) async {
    try {
      // Get current user
      Map<String, dynamic>? currentUser = await _authService.currentUser;

      await _dbHelper.insertLog({
        'id': UuidGenerator.generateUuid(),
        'description': description,
        'timestamp': DateTime.now().toIso8601String(),
        'type': type,
        'user': currentUser?['name'] ?? 'System',
        'ip': '127.0.0.1',
      });
    } catch (e) {
      print('Error logging activity: $e');
    }
  }
}
