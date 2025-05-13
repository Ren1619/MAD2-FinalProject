import 'package:flutter/foundation.dart';
import '../utils/uuid_generator.dart';
import 'database_helper.dart';
import 'auth_service.dart';

// Make DatabaseService extend ChangeNotifier for observer pattern
class DatabaseService extends ChangeNotifier {
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

  // Improved implementation of createBudget method in DatabaseService

  Future<bool> createBudget(Map<String, dynamic> budgetData) async {
    if (budgetData['name'] == null ||
        budgetData['budget'] == null ||
        budgetData['description'] == null) {
      print('Error: Missing required budget fields');
      return false;
    }

    try {
      // Get current user
      Map<String, dynamic>? currentUser = await _authService.currentUser;
      if (currentUser == null) {
        return false; // Cannot create budget without a user
      }

      // Add additional budget data
      String id = UuidGenerator.generateUuid();
      Map<String, dynamic> newBudget = {
        'id': id,
        ...budgetData,
        'dateSubmitted': DateTime.now().toIso8601String(),
        'status': 'Pending',
        'submittedBy': currentUser['id'],
        'submittedByEmail': currentUser['email'],
      };

      // Validate budget amount is a proper number
      double? budgetAmount;
      if (newBudget['budget'] is String) {
        budgetAmount = double.tryParse(newBudget['budget']);
        if (budgetAmount == null) return false;
        newBudget['budget'] = budgetAmount;
      } else if (newBudget['budget'] is int) {
        newBudget['budget'] = (newBudget['budget'] as int).toDouble();
      } else if (newBudget['budget'] is! double) {
        return false;
      }

      await _dbHelper.insertBudget(newBudget);

      // Log activity
      await logActivity(
        'New budget submitted: ${budgetData['name']} - ${_formatCurrency(newBudget['budget'])}',
        'Budget',
      );

      // Notify listeners about the change
      notifyListeners();

      return true;
    } catch (e) {
      print('Error creating budget: $e');
      return false;
    }
  }

  String _formatCurrency(dynamic amount) {
    if (amount == null) return '\$0.00';
    double numAmount;
    if (amount is double) {
      numAmount = amount;
    } else if (amount is int) {
      numAmount = amount.toDouble();
    } else if (amount is String) {
      numAmount = double.tryParse(amount) ?? 0.0;
    } else {
      numAmount = 0.0;
    }
    return '\$${numAmount.toStringAsFixed(2)}';
  }

  Future<List<Map<String, dynamic>>> getFilteredUsers(String filterType) async {
    try {
      if (filterType == "All") {
        return await _dbHelper.getUsers();
      } else if (filterType == "Active" || filterType == "Inactive") {
        return await _dbHelper.getUsersByStatus(filterType);
      } else if (filterType == "budget_manager") {
        return await _dbHelper.getUsersByRole("Budget Manager");
      } else if (filterType == "fp_manager") {
        return await _dbHelper.getUsersByRole(
          "Financial Planning and Analysis Manager",
        );
      } else if (filterType == "spender") {
        return await _dbHelper.getUsersByRole("Authorized Spender");
      } else {
        return await _dbHelper.getUsers();
      }
    } catch (e) {
      print('Error fetching filtered users: $e');
      return [];
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

      // Notify listeners about the change
      notifyListeners();

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
      // Get user details for logging
      Map<String, dynamic>? user = await _dbHelper.getUserById(userId);
      if (user == null) {
        return false;
      }

      // Update status
      await _dbHelper.updateUserStatus(userId, newStatus);

      // Log activity
      String description =
          'User status updated to $newStatus: ${user['email']}';
      await logActivity(description, 'Account Management');

      // Notify listeners about the change
      notifyListeners();

      return true;
    } catch (e) {
      print('Error updating user status: $e');
      return false;
    }
  }

  // User create method
  Future<bool> createUser(Map<String, dynamic> userData) async {
    try {
      // Check if user with this email already exists
      Map<String, dynamic>? existingUser = await _dbHelper.getUserByEmail(
        userData['email'],
      );

      if (existingUser != null) {
        return false; // User already exists
      }

      // Create new user
      String id = UuidGenerator.generateUuid();
      Map<String, dynamic> newUser = {
        'id': id,
        'name': userData['name'],
        'email': userData['email'],
        'role': userData['role'],
        'status': 'Active',
        'createdAt': DateTime.now().toIso8601String(),
      };

      await _dbHelper.insertUser(newUser);

      // Log activity
      await logActivity(
        'New account created: ${userData['email']}',
        'Account Management',
      );

      // Notify listeners about the change
      notifyListeners();

      return true;
    } catch (e) {
      print('Error creating user: $e');
      return false;
    }
  }

  // Delete user account
  Future<bool> deleteUser(String userId) async {
    try {
      // Get user details for logging before deletion
      Map<String, dynamic>? user = await _dbHelper.getUserById(userId);
      if (user == null) {
        return false;
      }

      // Delete user from database
      int result = await _dbHelper.deleteUser(userId);

      if (result <= 0) {
        return false; // Deletion failed
      }

      // Log activity
      await logActivity(
        'Account deleted: ${user['email']}',
        'Account Management',
      );

      // Notify listeners about the change
      notifyListeners();

      return true;
    } catch (e) {
      print('Error deleting user: $e');
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
      // Get current user information for the log
      Map<String, dynamic>? currentUser = await _authService.currentUser;
      String userName = 'System';

      if (currentUser != null) {
        userName = currentUser['name'];
      }

      await _dbHelper.insertLog({
        'id': UuidGenerator.generateUuid(),
        'description': description,
        'timestamp': DateTime.now().toIso8601String(),
        'type': type,
        'user': userName,
        'ip': '127.0.0.1',
      });

      // Notify listeners if this is a significant activity
      if (type != 'System') {
        notifyListeners();
      }
    } catch (e) {
      print('Error logging activity: $e');
    }
  }
}
