import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:moneyger_finalproject/services/app_logger.dart';
import '../utils/uuid_generator.dart';
import '../utils/image_utils.dart';

class FirebaseBudgetService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AppLogger _logger = AppLogger();

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
      final userDoc = await _firestore.collection('accounts').doc(_currentUserId).get();
      if (!userDoc.exists) return false;

      final userData = userDoc.data()!;
      final userRole = userData['role'];

      if (userRole != 'Financial Planning and Budgeting Officer') {
        await _logger.logUnauthorizedAccess('create_budget', userRole);
        throw 'Only Financial Planning and Budgeting Officers can create budgets';
      }

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
      int spendersAdded = 0;
      for (String spenderId in authorizedSpenderIds) {
        try {
          final authId = UuidGenerator.generateUuid();
          await _firestore.collection('budgets_authorized_spenders').doc(authId).set({
            'budget_auth_id': authId,
            'budget_id': budgetId,
            'account_id': spenderId,
            'created_at': FieldValue.serverTimestamp(),
          });
          spendersAdded++;
        } catch (e) {
          // Continue with other spenders
        }
      }

      // Log budget creation
      await _logger.logBudgetCreated(budgetName, budgetAmount, authorizedSpenderIds);

      return true;
    } catch (e) {
      return false;
    }
  }

  // Get budgets by status for current user's role
  Future<List<Map<String, dynamic>>> getBudgetsByStatus(String status) async {
    try {
      if (_currentUserId == null) return [];

      // Get current user data to determine role
      final userDoc = await _firestore.collection('accounts').doc(_currentUserId).get();
      if (!userDoc.exists) return [];

      final userData = userDoc.data()!;
      final userRole = userData['role'];
      final companyId = userData['company_id'];

      List<Map<String, dynamic>> budgets = [];

      switch (userRole) {
        case 'Administrator':
        case 'Budget Manager':
          try {
            final snapshot = await _firestore
                .collection('budgets')
                .where('company_id', isEqualTo: companyId)
                .where('status', isEqualTo: status)
                .get();

            budgets = await _processBudgetDocs(snapshot.docs);

            // Sort in dart instead of firestore
            budgets.sort((a, b) {
              final aTime = a['created_at'] as Timestamp?;
              final bTime = b['created_at'] as Timestamp?;
              if (aTime == null || bTime == null) return 0;
              return bTime.compareTo(aTime);
            });
          } catch (e) {
            // Try fallback query without compound index
            final snapshot = await _firestore
                .collection('budgets')
                .where('company_id', isEqualTo: companyId)
                .get();

            final allBudgets = await _processBudgetDocs(snapshot.docs);
            budgets = allBudgets.where((budget) => budget['status'] == status).toList();

            // Sort in dart
            budgets.sort((a, b) {
              final aTime = a['created_at'] as Timestamp?;
              final bTime = b['created_at'] as Timestamp?;
              if (aTime == null || bTime == null) return 0;
              return bTime.compareTo(aTime);
            });
          }
          break;

        case 'Financial Planning and Budgeting Officer':
          try {
            final snapshot = await _firestore
                .collection('budgets')
                .where('created_by', isEqualTo: _currentUserId)
                .where('status', isEqualTo: status)
                .get();

            budgets = await _processBudgetDocs(snapshot.docs);

            // Sort in dart
            budgets.sort((a, b) {
              final aTime = a['created_at'] as Timestamp?;
              final bTime = b['created_at'] as Timestamp?;
              if (aTime == null || bTime == null) return 0;
              return bTime.compareTo(aTime);
            });
          } catch (e) {
            // Try fallback query
            final snapshot = await _firestore
                .collection('budgets')
                .where('created_by', isEqualTo: _currentUserId)
                .get();

            final allBudgets = await _processBudgetDocs(snapshot.docs);
            budgets = allBudgets.where((budget) => budget['status'] == status).toList();

            // Sort in dart
            budgets.sort((a, b) {
              final aTime = a['created_at'] as Timestamp?;
              final bTime = b['created_at'] as Timestamp?;
              if (aTime == null || bTime == null) return 0;
              return bTime.compareTo(aTime);
            });
          }
          break;

        case 'Authorized Spender':
          budgets = await _getBudgetsForAuthorizedSpender(status);
          break;

        default:
          await _logger.logUnauthorizedAccess('view_budgets', userRole);
          return [];
      }

      return budgets;
    } catch (e) {
      return [];
    }
  }

  // Get budgets for authorized spender
  Future<List<Map<String, dynamic>>> _getBudgetsForAuthorizedSpender(String status) async {
    try {
      // Get all budget_auth records for this user
      final authSnapshot = await _firestore
          .collection('budgets_authorized_spenders')
          .where('account_id', isEqualTo: _currentUserId)
          .get();

      if (authSnapshot.docs.isEmpty) return [];

      // Get budget IDs
      final budgetIds = authSnapshot.docs
          .map((doc) => doc.data()['budget_id'] as String)
          .toList();

      // Get budgets with the specified status
      List<Map<String, dynamic>> budgets = [];

      for (String budgetId in budgetIds) {
        try {
          final budgetDoc = await _firestore.collection('budgets').doc(budgetId).get();

          if (budgetDoc.exists) {
            final budgetData = budgetDoc.data()!;

            if (budgetData['status'] == status) {
              final processedBudget = await _processBudgetDoc(budgetDoc);
              budgets.add(processedBudget);
            }
          }
        } catch (e) {
          // Continue with other budgets
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
      return [];
    }
  }

  // Process multiple budget documents
  Future<List<Map<String, dynamic>>> _processBudgetDocs(List<QueryDocumentSnapshot> docs) async {
    List<Map<String, dynamic>> budgets = [];

    for (var doc in docs) {
      try {
        final budgetData = await _processBudgetDoc(doc);
        budgets.add(budgetData);
      } catch (e) {
        // Continue with other budgets
      }
    }

    return budgets;
  }

  // Process single budget document with additional data
  Future<Map<String, dynamic>> _processBudgetDoc(DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;

    try {
      // Get creator information
      if (data['created_by'] != null) {
        try {
          final creatorDoc = await _firestore
              .collection('accounts')
              .doc(data['created_by'])
              .get();
          if (creatorDoc.exists) {
            final creatorData = creatorDoc.data()!;
            data['created_by_name'] = '${creatorData['f_name']} ${creatorData['l_name']}';
            data['created_by_email'] = creatorData['email'];
          } else {
            data['created_by_name'] = 'Unknown User';
          }
        } catch (e) {
          data['created_by_name'] = 'Unknown User';
        }
      }

      // Get authorized spenders
      try {
        final authSnapshot = await _firestore
            .collection('budgets_authorized_spenders')
            .where('budget_id', isEqualTo: data['budget_id'])
            .get();

        List<Map<String, dynamic>> authorizedSpenders = [];
        for (var authDoc in authSnapshot.docs) {
          try {
            final spenderDoc = await _firestore
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
          } catch (e) {
            // Continue with other spenders
          }
        }
        data['authorized_spenders'] = authorizedSpenders;
      } catch (e) {
        data['authorized_spenders'] = [];
      }

      // Get expenses summary
      try {
        final expensesSnapshot = await _firestore
            .collection('expenses')
            .where('budget_id', isEqualTo: data['budget_id'])
            .get();

        double totalExpenses = 0;
        int expenseCount = expensesSnapshot.docs.length;

        for (var expenseDoc in expensesSnapshot.docs) {
          final expenseData = expenseDoc.data();
          totalExpenses += (expenseData['expense_amt'] as num).toDouble();
        }

        data['total_expenses'] = totalExpenses;
        data['expense_count'] = expenseCount;
        data['remaining_amount'] = (data['budget_amount'] as num).toDouble() - totalExpenses;
      } catch (e) {
        data['total_expenses'] = 0.0;
        data['expense_count'] = 0;
        data['remaining_amount'] = data['budget_amount'] ?? 0.0;
      }

      return data;
    } catch (e) {
      return data;
    }
  }

  // Update budget status (Budget Manager only)
  Future<bool> updateBudgetStatus(String budgetId, String newStatus, {String? notes}) async {
    try {
      if (_currentUserId == null) return false;

      // Verify user is Budget Manager or Admin
      final userDoc = await _firestore.collection('accounts').doc(_currentUserId).get();
      if (!userDoc.exists) return false;

      final userRole = userDoc.data()!['role'];
      if (userRole != 'Budget Manager') {
        await _logger.logUnauthorizedAccess('update_budget_status', userRole);
        throw 'Only Budget Managers can update budget status';
      }

      // Get budget details before update
      final budgetDoc = await _firestore.collection('budgets').doc(budgetId).get();
      if (!budgetDoc.exists) return false;

      final budgetData = budgetDoc.data()!;
      final budgetName = budgetData['budget_name'];
      final oldStatus = budgetData['status'];

      Map<String, dynamic> updateData = {
        'status': newStatus,
        'updated_at': FieldValue.serverTimestamp(),
        'updated_by': _currentUserId,
      };

      if (notes != null) {
        updateData['notes'] = notes;
      }

      await _firestore.collection('budgets').doc(budgetId).update(updateData);

      // Log budget status change
      await _logger.logBudgetStatusChanged(budgetName, oldStatus, newStatus, notes: notes);

      return true;
    } catch (e) {
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
      final authSnapshot = await _firestore
          .collection('budgets_authorized_spenders')
          .where('budget_id', isEqualTo: budgetId)
          .where('account_id', isEqualTo: _currentUserId)
          .get();

      if (authSnapshot.docs.isEmpty) {
        await _logger.logUnauthorizedAccess('create_expense', 'unauthorized_spender');
        throw 'You are not authorized to create expenses for this budget';
      }

      final budgetAuthId = authSnapshot.docs.first.data()['budget_auth_id'];

      // Get budget info for company_id
      final budgetDoc = await _firestore.collection('budgets').doc(budgetId).get();
      if (!budgetDoc.exists) throw 'Budget not found';

      final budgetData = budgetDoc.data()!;
      final budgetName = budgetData['budget_name'];
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

      // Log expense creation
      await _logger.logExpenseCreated(
        expenseDescription,
        expenseAmount,
        budgetName,
        receiptBase64 != null,
      );

      return true;
    } catch (e) {
      return false;
    }
  }

  // Get expenses for a budget
  Future<List<Map<String, dynamic>>> getExpensesForBudget(String budgetId) async {
    try {
      final snapshot = await _firestore
          .collection('expenses')
          .where('budget_id', isEqualTo: budgetId)
          .get();

      // Sort in dart instead of using orderBy
      final docs = snapshot.docs;
      docs.sort((a, b) {
        final aTime = a.data()['created_at'] as Timestamp?;
        final bTime = b.data()['created_at'] as Timestamp?;
        if (aTime == null || bTime == null) return 0;
        return bTime.compareTo(aTime);
      });

      List<Map<String, dynamic>> expenses = [];

      for (var doc in docs) {
        try {
          final data = doc.data();

          // Get creator information
          if (data['created_by'] != null) {
            try {
              final creatorDoc = await _firestore
                  .collection('accounts')
                  .doc(data['created_by'])
                  .get();
              if (creatorDoc.exists) {
                final creatorData = creatorDoc.data()!;
                data['created_by_name'] = '${creatorData['f_name']} ${creatorData['l_name']}';
                data['created_by_email'] = creatorData['email'];
              } else {
                data['created_by_name'] = 'Unknown User';
              }
            } catch (e) {
              data['created_by_name'] = 'Unknown User';
            }
          }

          expenses.add(data);
        } catch (e) {
          // Continue with other expenses
        }
      }

      return expenses;
    } catch (e) {
      return [];
    }
  }

  // Update expense status (Budget Manager only)
  Future<bool> updateExpenseStatus(String expenseId, String newStatus, {String? notes}) async {
    try {
      if (_currentUserId == null) return false;

      // Verify user is Budget Manager or Admin
      final userDoc = await _firestore.collection('accounts').doc(_currentUserId).get();
      if (!userDoc.exists) return false;

      final userRole = userDoc.data()!['role'];
      if (userRole != 'Budget Manager') {
        await _logger.logUnauthorizedAccess('update_expense_status', userRole);
        throw 'Only Budget Managers can update expense status';
      }

      // Get expense details before update
      final expenseDoc = await _firestore.collection('expenses').doc(expenseId).get();
      if (!expenseDoc.exists) return false;

      final expenseData = expenseDoc.data()!;
      final description = expenseData['expense_desc'];
      final amount = (expenseData['expense_amt'] as num).toDouble();
      final oldStatus = expenseData['status'];

      Map<String, dynamic> updateData = {
        'status': newStatus,
        'updated_at': FieldValue.serverTimestamp(),
        'updated_by': _currentUserId,
      };

      if (notes != null) {
        updateData['notes'] = notes;
      }

      await _firestore.collection('expenses').doc(expenseId).update(updateData);

      // Log expense status change
      await _logger.logExpenseStatusChanged(description, amount, oldStatus, newStatus, notes: notes);

      return true;
    } catch (e) {
      return false;
    }
  }

  // Mark expense as fraudulent (Budget Manager only)
  Future<bool> markExpenseAsFraudulent(String expenseId, String reason) async {
    try {
      if (_currentUserId == null) return false;

      // Get expense details
      final expenseDoc = await _firestore.collection('expenses').doc(expenseId).get();
      if (!expenseDoc.exists) return false;

      final expenseData = expenseDoc.data()!;
      final description = expenseData['expense_desc'];
      final amount = (expenseData['expense_amt'] as num).toDouble();

      // Update expense status to fraudulent
      await _firestore.collection('expenses').doc(expenseId).update({
        'status': 'Fraudulent',
        'updated_at': FieldValue.serverTimestamp(),
        'updated_by': _currentUserId,
        'notes': reason,
      });

      // Log fraudulent expense (Critical security event)
      await _logger.logExpenseMarkedFraudulent(description, amount, reason);

      return true;
    } catch (e) {
      return false;
    }
  }

  // Get available authorized spenders for current user's company
  Future<List<Map<String, dynamic>>> getAvailableAuthorizedSpenders() async {
    try {
      if (_currentUserId == null) return [];

      // Get current user's company
      final userDoc = await _firestore.collection('accounts').doc(_currentUserId).get();
      if (!userDoc.exists) return [];

      final companyId = userDoc.data()!['company_id'];

      // Get all authorized spenders in the company
      final snapshot = await _firestore
          .collection('accounts')
          .where('company_id', isEqualTo: companyId)
          .where('role', isEqualTo: 'Authorized Spender')
          .where('status', isEqualTo: 'Active')
          .get();

      final spenders = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'account_id': data['account_id'],
          'name': '${data['f_name']} ${data['l_name']}',
          'email': data['email'],
          'contact_number': data['contact_number'] ?? '',
        };
      }).toList();

      return spenders;
    } catch (e) {
      return [];
    }
  }

  // Get budget details by ID
  Future<Map<String, dynamic>?> getBudgetById(String budgetId) async {
    try {
      final doc = await _firestore.collection('budgets').doc(budgetId).get();
      if (!doc.exists) return null;

      final budget = await _processBudgetDoc(doc);
      return budget;
    } catch (e) {
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
      if (data['created_by'] != null) {
        try {
          final creatorDoc = await _firestore
              .collection('accounts')
              .doc(data['created_by'])
              .get();
          if (creatorDoc.exists) {
            final creatorData = creatorDoc.data()!;
            data['created_by_name'] = '${creatorData['f_name']} ${creatorData['l_name']}';
            data['created_by_email'] = creatorData['email'];
          } else {
            data['created_by_name'] = 'Unknown User';
          }
        } catch (e) {
          data['created_by_name'] = 'Unknown User';
        }
      }

      // Get budget information
      if (data['budget_id'] != null) {
        try {
          final budgetDoc = await _firestore
              .collection('budgets')
              .doc(data['budget_id'])
              .get();
          if (budgetDoc.exists) {
            final budgetData = budgetDoc.data()!;
            data['budget_name'] = budgetData['budget_name'];
          }
        } catch (e) {
          // Continue without budget name
        }
      }

      return data;
    } catch (e) {
      return null;
    }
  }

  // Get pending approvals count for Budget Manager dashboard
  Future<int> getPendingApprovalsCount() async {
    try {
      if (_currentUserId == null) return 0;

      final userDoc = await _firestore.collection('accounts').doc(_currentUserId).get();
      if (!userDoc.exists) return 0;

      final companyId = userDoc.data()!['company_id'];

      // Count pending budgets
      final budgetsSnapshot = await _firestore
          .collection('budgets')
          .where('company_id', isEqualTo: companyId)
          .where('status', isEqualTo: STATUS_PENDING)
          .get();

      // Count pending expenses
      final expensesSnapshot = await _firestore
          .collection('expenses')
          .where('company_id', isEqualTo: companyId)
          .where('status', isEqualTo: 'Pending')
          .get();

      return budgetsSnapshot.docs.length + expensesSnapshot.docs.length;
    } catch (e) {
      return 0;
    }
  }

  // Test method to check if we can connect to Firestore and get budgets
  Future<List<Map<String, dynamic>>> testGetBudgets() async {
    try {
      // Get all budgets without any filtering
      final snapshot = await _firestore.collection('budgets').get();

      List<Map<String, dynamic>> budgets = [];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        budgets.add(data);
      }

      return budgets;
    } catch (e) {
      return [];
    }
  }
}