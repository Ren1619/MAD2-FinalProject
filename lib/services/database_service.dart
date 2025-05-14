import 'package:flutter/foundation.dart';
import '../utils/uuid_generator.dart';
import '../models/expense_model.dart';
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
        'companyId': currentUser['companyId'],
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

  // Expense methods
  Future<List<Map<String, dynamic>>> fetchExpenses({
    String? budgetId,
    String? category,
    String? status,
  }) async {
    try {
      // Get current user
      Map<String, dynamic>? currentUser = await _authService.currentUser;
      String? companyId = currentUser?['companyId'];

      return await _dbHelper.getExpenses(
        budgetId: budgetId,
        companyId: companyId,
        category: category,
        status: status,
      );
    } catch (e) {
      print('Error fetching expenses: $e');
      return [];
    }
  }

  Future<bool> createExpense(Map<String, dynamic> expenseData) async {
    if (expenseData['description'] == null ||
        expenseData['amount'] == null ||
        expenseData['category'] == null) {
      print('Error: Missing required expense fields');
      return false;
    }

    try {
      // Get current user
      Map<String, dynamic>? currentUser = await _authService.currentUser;
      if (currentUser == null) {
        return false; // Cannot create expense without a user
      }

      // Add additional expense data
      String id = UuidGenerator.generateUuid();
      Map<String, dynamic> newExpense = {
        'id': id,
        ...expenseData,
        'date': expenseData['date'] ?? DateTime.now().toIso8601String(),
        'status': 'Pending',
        'userId': currentUser['id'],
        'companyId': currentUser['companyId'],
      };

      // Validate amount is a proper number
      double? amount;
      if (newExpense['amount'] is String) {
        amount = double.tryParse(newExpense['amount']);
        if (amount == null) return false;
        newExpense['amount'] = amount;
      } else if (newExpense['amount'] is int) {
        newExpense['amount'] = (newExpense['amount'] as int).toDouble();
      } else if (newExpense['amount'] is! double) {
        return false;
      }

      await _dbHelper.insertExpense(newExpense);

      // Log activity
      await logActivity(
        'New expense submitted: ${expenseData['description']} - ${_formatCurrency(newExpense['amount'])}',
        'Budget',
      );

      // Notify listeners about the change
      notifyListeners();

      return true;
    } catch (e) {
      print('Error creating expense: $e');
      return false;
    }
  }

  Future<bool> updateExpenseStatus(String expenseId, String newStatus) async {
    try {
      // Get expense
      Map<String, dynamic>? expense = await _dbHelper.getExpenseById(expenseId);
      if (expense == null) {
        return false;
      }

      // Get current user for approver info
      Map<String, dynamic>? currentUser = await _authService.currentUser;
      String? approverName = currentUser?['name'];

      // Update status
      await _dbHelper.updateExpenseStatus(
        expenseId,
        newStatus,
        approvedBy: newStatus == 'Approved' ? approverName : null,
      );

      // Log activity
      String description =
          'Expense status updated to $newStatus: ${expense['description']}';
      await logActivity(description, 'Budget');

      // Notify listeners about the change
      notifyListeners();

      return true;
    } catch (e) {
      print('Error updating expense status: $e');
      return false;
    }
  }

  Future<bool> updateExpense(Map<String, dynamic> expenseData) async {
    if (expenseData['id'] == null ||
        expenseData['description'] == null ||
        expenseData['amount'] == null ||
        expenseData['category'] == null) {
      print('Error: Missing required expense fields');
      return false;
    }

    try {
      // Validate amount is a proper number
      if (expenseData['amount'] is String) {
        final amount = double.tryParse(expenseData['amount']);
        if (amount == null) return false;
        expenseData['amount'] = amount;
      } else if (expenseData['amount'] is int) {
        expenseData['amount'] = (expenseData['amount'] as int).toDouble();
      } else if (expenseData['amount'] is! double) {
        return false;
      }

      await _dbHelper.updateExpense(expenseData);

      // Log activity
      await logActivity(
        'Expense updated: ${expenseData['description']}',
        'Budget',
      );

      // Notify listeners about the change
      notifyListeners();

      return true;
    } catch (e) {
      print('Error updating expense: $e');
      return false;
    }
  }

  Future<bool> deleteExpense(String expenseId) async {
    try {
      // Get expense details for logging
      Map<String, dynamic>? expense = await _dbHelper.getExpenseById(expenseId);
      if (expense == null) {
        return false;
      }

      // Delete expense
      await _dbHelper.deleteExpense(expenseId);

      // Log activity
      await logActivity('Expense deleted: ${expense['description']}', 'Budget');

      // Notify listeners about the change
      notifyListeners();

      return true;
    } catch (e) {
      print('Error deleting expense: $e');
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
      // Get current user for company ID and to check if they're an admin
      Map<String, dynamic>? currentUser = await _authService.currentUser;
      if (currentUser == null ||
          currentUser['role'] != AuthService.ROLE_COMPANY_ADMIN ||
          currentUser['companyId'] == null) {
        return false; // Only company admins can create users
      }

      // Check if user with this email already exists
      Map<String, dynamic>? existingUser = await _dbHelper.getUserByEmail(
        userData['email'],
      );

      if (existingUser != null) {
        return false; // User already exists
      }

      // Create new user with current user's company ID
      String id = UuidGenerator.generateUuid();
      Map<String, dynamic> newUser = {
        'id': id,
        'name': userData['name'],
        'email': userData['email'],
        'role': userData['role'],
        'status': 'Active',
        'createdAt': DateTime.now().toIso8601String(),
        'companyId': currentUser['companyId'],
        'phone': userData['phone'] ?? '',
        'enableNotifications': userData['enableNotifications'] ?? 1,
      };

      await _dbHelper.insertUser(newUser);

      // Log activity
      await logActivity(
        'New account created: ${userData['email']} with role: ${userData['role']}',
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
      String? companyId;

      if (currentUser != null) {
        userName = currentUser['name'];
        companyId = currentUser['companyId'];
      }

      await _dbHelper.insertLog({
        'id': UuidGenerator.generateUuid(),
        'description': description,
        'timestamp': DateTime.now().toIso8601String(),
        'type': type,
        'user': userName,
        'ip': '127.0.0.1',
        'companyId': companyId,
      });

      // Notify listeners if this is a significant activity
      if (type != 'System') {
        notifyListeners();
      }
    } catch (e) {
      print('Error logging activity: $e');
    }
  }

  // Update an existing budget
  Future<bool> updateBudget(Map<String, dynamic> budget) async {
    if (budget['id'] == null) {
      print('Error: Missing budget ID');
      return false;
    }

    try {
      // Validate budget fields
      if (budget['name'] == null ||
          budget['budget'] == null ||
          budget['description'] == null) {
        print('Error: Missing required budget fields');
        return false;
      }

      // Get current user
      Map<String, dynamic>? currentUser = await _authService.currentUser;
      if (currentUser == null) {
        return false; // Cannot update budget without a user
      }

      // Ensure the budget amount is a proper number
      double budgetAmount;
      if (budget['budget'] is String) {
        budgetAmount = double.tryParse(budget['budget']) ?? 0.0;
        budget['budget'] = budgetAmount;
      } else if (budget['budget'] is int) {
        budget['budget'] = (budget['budget'] as int).toDouble();
      } else if (budget['budget'] is! double) {
        return false;
      }

      // Update the budget in the database
      await _dbHelper.updateBudget(budget);

      // Log activity
      await logActivity('Budget updated: ${budget['name']}', 'Budget');

      // Notify listeners about the change
      notifyListeners();

      return true;
    } catch (e) {
      print('Error updating budget: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> fetchAuthorizedBudgets() async {
    try {
      // Get current user
      Map<String, dynamic>? currentUser = await _authService.currentUser;

      if (currentUser == null || currentUser['id'] == null) {
        return [];
      }

      String userId = currentUser['id'];

      // Get all budgets
      List<Map<String, dynamic>> allBudgets = await _dbHelper.getBudgets();

      // Filter budgets where this user is an authorized spender
      List<Map<String, dynamic>> authorizedBudgets =
          allBudgets.where((budget) {
            List<dynamic> authorizedSpenders =
                budget['authorizedSpenders'] ?? [];
            return authorizedSpenders.contains(userId);
          }).toList();

      return authorizedBudgets;
    } catch (e) {
      print('Error fetching authorized budgets: $e');
      return [];
    }
  }

  // Get Budget by ID
  Future<Map<String, dynamic>?> getBudgetById(String budgetId) async {
    try {
      return await _dbHelper.getBudgetById(budgetId);
    } catch (e) {
      print('Error getting budget by ID: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> fetchExpensesWithBudgetInfo({
    String? status,
    String? category,
  }) async {
    try {
      List<Map<String, dynamic>> expenses = await _dbHelper.getExpenses(
        status: status,
        category: category,
      );

      // Enhance each expense with budget information
      for (int i = 0; i < expenses.length; i++) {
        final String? budgetId = expenses[i]['budgetId'];

        if (budgetId != null) {
          Map<String, dynamic>? budget = await _dbHelper.getBudgetById(
            budgetId,
          );

          if (budget != null) {
            expenses[i]['budgetName'] = budget['name'];
            expenses[i]['budgetStatus'] = budget['status'];
          }
        }
      }

      return expenses;
    } catch (e) {
      print('Error fetching expenses with budget info: $e');
      return [];
    }
  }

  // Mark an expense as fraudulent with a reason
  Future<bool> markExpenseAsFraudulent(String expenseId, String reason) async {
    try {
      // Get expense details for logging
      Map<String, dynamic>? expense = await _dbHelper.getExpenseById(expenseId);

      if (expense == null) {
        return false;
      }

      // Update expense status
      await _dbHelper.updateExpenseStatus(expenseId, 'Fraudulent');

      // Add reason as a note
      await _dbHelper.updateExpense({'id': expenseId, 'fraudReason': reason});

      // Log the activity
      await logActivity(
        'Expense marked as fraudulent: ${expense['description']} - Reason: $reason',
        'Budget',
      );

      // Notify listeners about the change
      notifyListeners();

      return true;
    } catch (e) {
      print('Error marking expense as fraudulent: $e');
      return false;
    }
  }
}
