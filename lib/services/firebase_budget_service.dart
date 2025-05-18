import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/uuid_generator.dart';
import '../utils/image_utils.dart';

class FirebaseBudgetService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Budget status constants
  static const String STATUS_PENDING = 'Pending for Approval';
  static const String STATUS_ACTIVE = 'Active';
  static const String STATUS_COMPLETED = 'Completed';
  static const String STATUS_FOR_REVISION = 'For Revision';

  // Get current user ID
  String? get _currentUserId => _auth.currentUser?.uid;

  // Create a new budget (Financial Officer only)
  Future<bool> createBudget({
    required String budgetName,
    required double budgetAmount,
    required String budgetDescription,
    required List<String> authorizedSpenderIds,
  }) async {
    try {
      if (_currentUserId == null) return false;

      // Verify user is Financial Officer
      final userDoc =
          await _firestore.collection('accounts').doc(_currentUserId).get();
      if (!userDoc.exists ||
          userDoc.data()!['role'] !=
              'Financial Planning and Budgeting Officer') {
        throw 'Only Financial Planning and Budgeting Officers can create budgets';
      }

      final userData = userDoc.data()!;
      final companyId = userData['company_id'];

      // Create budget document
      final budgetId = UuidGenerator.generateUuid();
      await _firestore.collection('budgets').doc(budgetId).set({
        'budget_id': budgetId,
        'budget_name': budgetName,
        'budget_amount': budgetAmount,
        'budget_description': budgetDescription,
        'status': STATUS_PENDING,
        'created_by': _currentUserId,
        'company_id': companyId,
        'created_at': FieldValue.serverTimestamp(),
      });

      // Create authorized spenders records
      for (String spenderId in authorizedSpenderIds) {
        final authId = UuidGenerator.generateUuid();
        await _firestore
            .collection('budgets_authorized_spenders')
            .doc(authId)
            .set({
              'budget_auth_id': authId,
              'budget_id': budgetId,
              'account_id': spenderId,
              'created_at': FieldValue.serverTimestamp(),
            });
      }

      // Log activity
      await _logActivity(
        'New budget created: $budgetName - \$${budgetAmount.toStringAsFixed(2)}',
        'Budget Management',
        companyId,
      );

      return true;
    } catch (e) {
      print('Error creating budget: $e');
      return false;
    }
  }

  // Get budgets by status for current user's role
  Future<List<Map<String, dynamic>>> getBudgetsByStatus(String status) async {
    try {
      if (_currentUserId == null) return [];

      // Get current user data to determine role
      final userDoc =
          await _firestore.collection('accounts').doc(_currentUserId).get();
      if (!userDoc.exists) return [];

      final userData = userDoc.data()!;
      final userRole = userData['role'];
      final companyId = userData['company_id'];

      List<Map<String, dynamic>> budgets = [];

      switch (userRole) {
        case 'Administrator':
        case 'Budget Manager':
          // Admin and Budget Manager can see all budgets in their company
          final snapshot =
              await _firestore
                  .collection('budgets')
                  .where('company_id', isEqualTo: companyId)
                  .where('status', isEqualTo: status)
                  .orderBy('created_at', descending: true)
                  .get();

          budgets = await _processBudgetDocs(snapshot.docs);
          break;

        case 'Financial Planning and Budgeting Officer':
          // Financial Officer can only see budgets they created
          final snapshot =
              await _firestore
                  .collection('budgets')
                  .where('created_by', isEqualTo: _currentUserId)
                  .where('status', isEqualTo: status)
                  .orderBy('created_at', descending: true)
                  .get();

          budgets = await _processBudgetDocs(snapshot.docs);
          break;

        case 'Authorized Spender':
          // Authorized Spenders can only see budgets they are assigned to
          budgets = await _getBudgetsForAuthorizedSpender(status);
          break;
      }

      return budgets;
    } catch (e) {
      print('Error getting budgets by status: $e');
      return [];
    }
  }

  // Get budgets for authorized spender
  Future<List<Map<String, dynamic>>> _getBudgetsForAuthorizedSpender(
    String status,
  ) async {
    try {
      // Get all budget_auth records for this user
      final authSnapshot =
          await _firestore
              .collection('budgets_authorized_spenders')
              .where('account_id', isEqualTo: _currentUserId)
              .get();

      if (authSnapshot.docs.isEmpty) return [];

      // Get budget IDs
      final budgetIds =
          authSnapshot.docs
              .map((doc) => doc.data()['budget_id'] as String)
              .toList();

      // Get budgets with the specified status
      List<Map<String, dynamic>> budgets = [];
      for (String budgetId in budgetIds) {
        final budgetDoc =
            await _firestore.collection('budgets').doc(budgetId).get();
        if (budgetDoc.exists && budgetDoc.data()!['status'] == status) {
          final budgetData = await _processBudgetDoc(budgetDoc);
          budgets.add(budgetData);
        }
      }

      // Sort by created_at descending
      budgets.sort((a, b) {
        final aTime = a['created_at'] as Timestamp?;
        final bTime = b['created_at'] as Timestamp?;
        if (aTime == null || bTime == null) return 0;
        return bTime.compareTo(aTime);
      });

      return budgets;
    } catch (e) {
      print('Error getting budgets for authorized spender: $e');
      return [];
    }
  }

  // Process multiple budget documents
  Future<List<Map<String, dynamic>>> _processBudgetDocs(
    List<QueryDocumentSnapshot> docs,
  ) async {
    List<Map<String, dynamic>> budgets = [];
    for (var doc in docs) {
      final budgetData = await _processBudgetDoc(doc);
      budgets.add(budgetData);
    }
    return budgets;
  }

  // Process single budget document with additional data
  Future<Map<String, dynamic>> _processBudgetDoc(DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;

    // Get creator information
    final creatorDoc =
        await _firestore.collection('accounts').doc(data['created_by']).get();
    if (creatorDoc.exists) {
      final creatorData = creatorDoc.data()!;
      data['created_by_name'] =
          '${creatorData['f_name']} ${creatorData['l_name']}';
      data['created_by_email'] = creatorData['email'];
    }

    // Get authorized spenders
    final authSnapshot =
        await _firestore
            .collection('budgets_authorized_spenders')
            .where('budget_id', isEqualTo: data['budget_id'])
            .get();

    List<Map<String, dynamic>> authorizedSpenders = [];
    for (var authDoc in authSnapshot.docs) {
      final spenderDoc =
          await _firestore
              .collection('accounts')
              .doc(authDoc.data()['account_id'])
              .get();
      if (spenderDoc.exists) {
        final spenderData = spenderDoc.data()!;
        authorizedSpenders.add({
          'account_id': spenderData['account_id'],
          'name': '${spenderData['f_name']} ${spenderData['l_name']}',
          'email': spenderData['email'],
        });
      }
    }
    data['authorized_spenders'] = authorizedSpenders;

    // Get expenses summary
    final expensesSnapshot =
        await _firestore
            .collection('expenses')
            .where('budget_id', isEqualTo: data['budget_id'])
            .get();

    double totalExpenses = 0;
    int expenseCount = expensesSnapshot.docs.length;
    for (var expenseDoc in expensesSnapshot.docs) {
      totalExpenses += (expenseDoc.data()['expense_amt'] as num).toDouble();
    }

    data['total_expenses'] = totalExpenses;
    data['expense_count'] = expenseCount;
    data['remaining_amount'] = data['budget_amount'] - totalExpenses;

    return data;
  }

  // Update budget status (Budget Manager only)
  Future<bool> updateBudgetStatus(
    String budgetId,
    String newStatus, {
    String? notes,
  }) async {
    try {
      if (_currentUserId == null) return false;

      // Verify user is Budget Manager or Admin
      final userDoc =
          await _firestore.collection('accounts').doc(_currentUserId).get();
      if (!userDoc.exists) return false;

      final userRole = userDoc.data()!['role'];
      if (userRole != 'Budget Manager' && userRole != 'Administrator') {
        throw 'Only Budget Managers and Administrators can update budget status';
      }

      Map<String, dynamic> updateData = {
        'status': newStatus,
        'updated_at': FieldValue.serverTimestamp(),
        'updated_by': _currentUserId,
      };

      if (notes != null) {
        updateData['notes'] = notes;
      }

      await _firestore.collection('budgets').doc(budgetId).update(updateData);

      // Get budget details for logging
      final budgetDoc =
          await _firestore.collection('budgets').doc(budgetId).get();
      if (budgetDoc.exists) {
        final budgetData = budgetDoc.data()!;
        await _logActivity(
          'Budget status updated to $newStatus: ${budgetData['budget_name']}',
          'Budget Management',
          budgetData['company_id'],
        );
      }

      return true;
    } catch (e) {
      print('Error updating budget status: $e');
      return false;
    }
  }

  // Create expense (Authorized Spender only)
  Future<bool> createExpense({
    required String budgetId,
    required String expenseDescription,
    required double expenseAmount,
    String? receiptBase64, // Base64 encoded receipt image
  }) async {
    try {
      if (_currentUserId == null) return false;

      // Verify user is authorized spender for this budget
      final authSnapshot =
          await _firestore
              .collection('budgets_authorized_spenders')
              .where('budget_id', isEqualTo: budgetId)
              .where('account_id', isEqualTo: _currentUserId)
              .get();

      if (authSnapshot.docs.isEmpty) {
        throw 'You are not authorized to create expenses for this budget';
      }

      final budgetAuthId = authSnapshot.docs.first.data()['budget_auth_id'];

      // Get budget info for company_id
      final budgetDoc =
          await _firestore.collection('budgets').doc(budgetId).get();
      if (!budgetDoc.exists) throw 'Budget not found';

      final budgetData = budgetDoc.data()!;
      final companyId = budgetData['company_id'];

      // Create expense document
      final expenseId = UuidGenerator.generateUuid();
      Map<String, dynamic> expenseData = {
        'expense_id': expenseId,
        'budget_auth_id': budgetAuthId,
        'budget_id': budgetId,
        'expense_desc': expenseDescription,
        'expense_amt': expenseAmount,
        'status': 'Pending',
        'created_by': _currentUserId,
        'company_id': companyId,
        'created_at': FieldValue.serverTimestamp(),
      };

      // Add receipt if provided
      if (receiptBase64 != null) {
        expenseData['receipt_image'] = receiptBase64;
        expenseData['has_receipt'] = true;
      } else {
        expenseData['has_receipt'] = false;
      }

      await _firestore.collection('expenses').doc(expenseId).set(expenseData);

      // Log activity
      await _logActivity(
        'New expense created: $expenseDescription - \$${expenseAmount.toStringAsFixed(2)}',
        'Expense Management',
        companyId,
      );

      return true;
    } catch (e) {
      print('Error creating expense: $e');
      return false;
    }
  }

  // Get expenses for a budget
  Future<List<Map<String, dynamic>>> getExpensesForBudget(
    String budgetId,
  ) async {
    try {
      final snapshot =
          await _firestore
              .collection('expenses')
              .where('budget_id', isEqualTo: budgetId)
              .orderBy('created_at', descending: true)
              .get();

      List<Map<String, dynamic>> expenses = [];
      for (var doc in snapshot.docs) {
        final data = doc.data();

        // Get creator information
        final creatorDoc =
            await _firestore
                .collection('accounts')
                .doc(data['created_by'])
                .get();
        if (creatorDoc.exists) {
          final creatorData = creatorDoc.data()!;
          data['created_by_name'] =
              '${creatorData['f_name']} ${creatorData['l_name']}';
          data['created_by_email'] = creatorData['email'];
        }

        expenses.add(data);
      }

      return expenses;
    } catch (e) {
      print('Error getting expenses for budget: $e');
      return [];
    }
  }

  // Update expense status (Budget Manager only)
  Future<bool> updateExpenseStatus(
    String expenseId,
    String newStatus, {
    String? notes,
  }) async {
    try {
      if (_currentUserId == null) return false;

      // Verify user is Budget Manager or Admin
      final userDoc =
          await _firestore.collection('accounts').doc(_currentUserId).get();
      if (!userDoc.exists) return false;

      final userRole = userDoc.data()!['role'];
      if (userRole != 'Budget Manager' && userRole != 'Administrator') {
        throw 'Only Budget Managers and Administrators can update expense status';
      }

      Map<String, dynamic> updateData = {
        'status': newStatus,
        'updated_at': FieldValue.serverTimestamp(),
        'updated_by': _currentUserId,
      };

      if (notes != null) {
        updateData['notes'] = notes;
      }

      await _firestore.collection('expenses').doc(expenseId).update(updateData);

      // Get expense details for logging
      final expenseDoc =
          await _firestore.collection('expenses').doc(expenseId).get();
      if (expenseDoc.exists) {
        final expenseData = expenseDoc.data()!;
        await _logActivity(
          'Expense status updated to $newStatus: ${expenseData['expense_desc']}',
          'Expense Management',
          expenseData['company_id'],
        );
      }

      return true;
    } catch (e) {
      print('Error updating expense status: $e');
      return false;
    }
  }

  // Mark expense as fraudulent (Budget Manager only)
  Future<bool> markExpenseAsFraudulent(String expenseId, String reason) async {
    try {
      return await updateExpenseStatus(expenseId, 'Fraudulent', notes: reason);
    } catch (e) {
      print('Error marking expense as fraudulent: $e');
      return false;
    }
  }

  // Get available authorized spenders for current user's company
  Future<List<Map<String, dynamic>>> getAvailableAuthorizedSpenders() async {
    try {
      if (_currentUserId == null) return [];

      // Get current user's company
      final userDoc =
          await _firestore.collection('accounts').doc(_currentUserId).get();
      if (!userDoc.exists) return [];

      final companyId = userDoc.data()!['company_id'];

      // Get all authorized spenders in the company
      final snapshot =
          await _firestore
              .collection('accounts')
              .where('company_id', isEqualTo: companyId)
              .where('role', isEqualTo: 'Authorized Spender')
              .where('status', isEqualTo: 'Active')
              .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'account_id': data['account_id'],
          'name': '${data['f_name']} ${data['l_name']}',
          'email': data['email'],
          'contact_number': data['contact_number'] ?? '',
        };
      }).toList();
    } catch (e) {
      print('Error getting authorized spenders: $e');
      return [];
    }
  }

  // Get budget details by ID
  Future<Map<String, dynamic>?> getBudgetById(String budgetId) async {
    try {
      final doc = await _firestore.collection('budgets').doc(budgetId).get();
      if (!doc.exists) return null;

      return await _processBudgetDoc(doc);
    } catch (e) {
      print('Error getting budget by ID: $e');
      return null;
    }
  }

  // Get expense details by ID
  Future<Map<String, dynamic>?> getExpenseById(String expenseId) async {
    try {
      final doc = await _firestore.collection('expenses').doc(expenseId).get();
      if (!doc.exists) return null;

      final data = doc.data()!;

      // Get creator information
      final creatorDoc =
          await _firestore.collection('accounts').doc(data['created_by']).get();
      if (creatorDoc.exists) {
        final creatorData = creatorDoc.data()!;
        data['created_by_name'] =
            '${creatorData['f_name']} ${creatorData['l_name']}';
        data['created_by_email'] = creatorData['email'];
      }

      // Get budget information
      final budgetDoc =
          await _firestore.collection('budgets').doc(data['budget_id']).get();
      if (budgetDoc.exists) {
        final budgetData = budgetDoc.data()!;
        data['budget_name'] = budgetData['budget_name'];
      }

      return data;
    } catch (e) {
      print('Error getting expense by ID: $e');
      return null;
    }
  }

  // Private helper method to log activities
  Future<void> _logActivity(
    String description,
    String type,
    String companyId,
  ) async {
    try {
      await _firestore.collection('logs').add({
        'log_id': UuidGenerator.generateUuid(),
        'log_desc': description,
        'type': type,
        'company_id': companyId,
        'user_id': _currentUserId,
        'created_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error logging activity: $e');
    }
  }

  // Get pending approvals count for Budget Manager dashboard
  Future<int> getPendingApprovalsCount() async {
    try {
      if (_currentUserId == null) return 0;

      final userDoc =
          await _firestore.collection('accounts').doc(_currentUserId).get();
      if (!userDoc.exists) return 0;

      final companyId = userDoc.data()!['company_id'];

      // Count pending budgets
      final budgetsSnapshot =
          await _firestore
              .collection('budgets')
              .where('company_id', isEqualTo: companyId)
              .where('status', isEqualTo: STATUS_PENDING)
              .get();

      // Count pending expenses
      final expensesSnapshot =
          await _firestore
              .collection('expenses')
              .where('company_id', isEqualTo: companyId)
              .where('status', isEqualTo: 'Pending')
              .get();

      return budgetsSnapshot.docs.length + expensesSnapshot.docs.length;
    } catch (e) {
      print('Error getting pending approvals count: $e');
      return 0;
    }
  }
}
