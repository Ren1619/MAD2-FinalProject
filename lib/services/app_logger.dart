import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../utils/uuid_generator.dart';

class AppLogger {
  static final AppLogger _instance = AppLogger._internal();
  factory AppLogger() => _instance;
  AppLogger._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Cache for user context to avoid repeated queries
  Map<String, dynamic>? _cachedUserContext;
  DateTime? _lastUserContextUpdate;
  static const Duration _contextCacheTimeout = Duration(minutes: 5);
  static const String _appVersion = '1.0.0';

  /// Initialize the logger (call this when app starts)
  Future<void> initialize() async {
    await _loadUserContext();
  }

  /// Load user context and cache it
  Future<void> _loadUserContext() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        _cachedUserContext = null;
        return;
      }

      final userDoc =
          await _firestore.collection('accounts').doc(user.uid).get();
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        _cachedUserContext = {
          'user_id': user.uid,
          'company_id': userData['company_id'],
          'user_name': '${userData['f_name']} ${userData['l_name']}',
          'user_role': userData['role'],
          'user_email': userData['email'],
        };
        _lastUserContextUpdate = DateTime.now();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading user context: $e');
      }
    }
  }

  /// Get current user context (with caching)
  Future<Map<String, dynamic>> _getCurrentContext() async {
    // Check if cache is expired or empty
    if (_cachedUserContext == null ||
        _lastUserContextUpdate == null ||
        DateTime.now().difference(_lastUserContextUpdate!) >
            _contextCacheTimeout) {
      await _loadUserContext();
    }

    return _cachedUserContext ?? {};
  }

  /// Main logging method - simplified for major events only
  Future<void> _createLog({
    required String message,
    required String category,
    required String type,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final context = await _getCurrentContext();

      final logEntry = {
        'log_id': UuidGenerator.generateUuid(),
        'message': message,
        'log_desc': message, // For compatibility
        'level': 'info', // Simplified - only info level for major events
        'category': category,
        'type': type, // For compatibility with existing UI
        'timestamp': FieldValue.serverTimestamp(),
        'created_at': FieldValue.serverTimestamp(), // For compatibility
        'client_timestamp': DateTime.now().toIso8601String(),
        'app_version': _appVersion,
        'platform': kIsWeb ? 'web' : 'mobile',
        ...context,
        if (additionalData != null) ...additionalData,
      };

      // Store in Firestore
      await _firestore.collection('logs').add(logEntry);

      // Debug output
      if (kDebugMode) {
        print('📝 LOG: $message');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to create log: $e');
      }
    }
  } // ============================================================================
  // AUTHENTICATION EVENTS
  // ============================================================================

  /// Log user login
  Future<void> logLogin(String email, {bool success = true}) async {
    await _createLog(
      message:
          success
              ? 'User logged in successfully: $email'
              : 'Failed login attempt: $email',
      category: 'authentication',
      type: 'Authentication',
      additionalData: {'action': 'login', 'email': email, 'success': success},
    );
  }

  /// Log user logout
  Future<void> logLogout(String email) async {
    await _createLog(
      message: 'User logged out: $email',
      category: 'authentication',
      type: 'Authentication',
      additionalData: {'action': 'logout', 'email': email},
    );
  }

  /// Log company registration
  Future<void> logCompanyRegistration(
    String companyName,
    String adminEmail,
  ) async {
    await _createLog(
      message: 'New company registered: $companyName',
      category: 'authentication',
      type: 'Authentication',
      additionalData: {
        'action': 'company_registration',
        'company_name': companyName,
        'admin_email': adminEmail,
      },
    );
  }

  // ============================================================================
  // ACCOUNT CRUD OPERATIONS
  // ============================================================================

  /// Log account creation
  Future<void> logAccountCreated(
    String email,
    String role,
    String? targetName,
  ) async {
    await _createLog(
      message: 'New account created: ${targetName ?? email} as $role',
      category: 'accountManagement',
      type: 'Account Management',
      additionalData: {
        'action': 'create',
        'target_email': email,
        'target_role': role,
        'target_name': targetName,
      },
    );
  }

  /// Log account update
  Future<void> logAccountUpdated(
    String email,
    String? targetName,
    List<String> updatedFields,
  ) async {
    await _createLog(
      message: 'Account updated: ${targetName ?? email}',
      category: 'accountManagement',
      type: 'Account Management',
      additionalData: {
        'action': 'update',
        'target_email': email,
        'target_name': targetName,
        'updated_fields': updatedFields,
      },
    );
  }

  /// Log account deletion
  Future<void> logAccountDeleted(String email, String? targetName) async {
    await _createLog(
      message: 'Account deleted: ${targetName ?? email}',
      category: 'accountManagement',
      type: 'Account Management',
      additionalData: {
        'action': 'delete',
        'target_email': email,
        'target_name': targetName,
      },
    );
  }

  /// Log account status change
  Future<void> logAccountStatusChanged(
    String email,
    String? targetName,
    String oldStatus,
    String newStatus,
  ) async {
    await _createLog(
      message:
          'Account status changed: ${targetName ?? email} from $oldStatus to $newStatus',
      category: 'accountManagement',
      type: 'Account Management',
      additionalData: {
        'action': 'status_change',
        'target_email': email,
        'target_name': targetName,
        'old_status': oldStatus,
        'new_status': newStatus,
      },
    );
  }

  // ============================================================================
  // BUDGET CRUD OPERATIONS
  // ============================================================================

  /// Log budget creation
  Future<void> logBudgetCreated(
    String budgetName,
    double amount,
    List<String> authorizedSpenders,
  ) async {
    await _createLog(
      message: 'Budget created: $budgetName (\$${amount.toStringAsFixed(2)})',
      category: 'budgetManagement',
      type: 'Budget Management',
      additionalData: {
        'action': 'create',
        'budget_name': budgetName,
        'budget_amount': amount,
        'authorized_spenders_count': authorizedSpenders.length,
      },
    );
  }

  /// Log budget status change
  Future<void> logBudgetStatusChanged(
    String budgetName,
    String oldStatus,
    String newStatus, {
    String? notes,
  }) async {
    await _createLog(
      message:
          'Budget status changed: $budgetName from $oldStatus to $newStatus',
      category: 'budgetManagement',
      type: 'Budget Management',
      additionalData: {
        'action': 'status_change',
        'budget_name': budgetName,
        'old_status': oldStatus,
        'new_status': newStatus,
        if (notes != null) 'notes': notes,
      },
    );
  }

  /// Log budget update
  Future<void> logBudgetUpdated(
    String budgetName,
    List<String> updatedFields,
  ) async {
    await _createLog(
      message: 'Budget updated: $budgetName',
      category: 'budgetManagement',
      type: 'Budget Management',
      additionalData: {
        'action': 'update',
        'budget_name': budgetName,
        'updated_fields': updatedFields,
      },
    );
  }

  /// Log budget deletion
  Future<void> logBudgetDeleted(String budgetName) async {
    await _createLog(
      message: 'Budget deleted: $budgetName',
      category: 'budgetManagement',
      type: 'Budget Management',
      additionalData: {'action': 'delete', 'budget_name': budgetName},
    );
  }

  // ============================================================================
  // EXPENSE CRUD OPERATIONS
  // ============================================================================

  /// Log expense creation
  Future<void> logExpenseCreated(
    String description,
    double amount,
    String budgetName,
    bool hasReceipt,
  ) async {
    await _createLog(
      message:
          'Expense created: $description (\$${amount.toStringAsFixed(2)}) for $budgetName',
      category: 'expenseManagement',
      type: 'Expense Management',
      additionalData: {
        'action': 'create',
        'expense_description': description,
        'expense_amount': amount,
        'budget_name': budgetName,
        'has_receipt': hasReceipt,
      },
    );
  }

  /// Log expense status change
  Future<void> logExpenseStatusChanged(
    String description,
    double amount,
    String oldStatus,
    String newStatus, {
    String? notes,
  }) async {
    await _createLog(
      message:
          'Expense status changed: $description (\$${amount.toStringAsFixed(2)}) from $oldStatus to $newStatus',
      category: 'expenseManagement',
      type: 'Expense Management',
      additionalData: {
        'action': 'status_change',
        'expense_description': description,
        'expense_amount': amount,
        'old_status': oldStatus,
        'new_status': newStatus,
        if (notes != null) 'notes': notes,
      },
    );
  }

  /// Log expense marked as fraudulent (CRITICAL EVENT)
  Future<void> logExpenseMarkedFraudulent(
    String description,
    double amount,
    String reason,
  ) async {
    await _createLog(
      message:
          'SECURITY ALERT: Expense marked as fraudulent: $description (\$${amount.toStringAsFixed(2)}) - Reason: $reason',
      category: 'security',
      type: 'Security',
      additionalData: {
        'action': 'mark_fraudulent',
        'expense_description': description,
        'expense_amount': amount,
        'fraud_reason': reason,
        'severity': 'critical',
      },
    );
  }

  /// Log expense update
  Future<void> logExpenseUpdated(
    String description,
    double amount,
    List<String> updatedFields,
  ) async {
    await _createLog(
      message: 'Expense updated: $description (\$${amount.toStringAsFixed(2)})',
      category: 'expenseManagement',
      type: 'Expense Management',
      additionalData: {
        'action': 'update',
        'expense_description': description,
        'expense_amount': amount,
        'updated_fields': updatedFields,
      },
    );
  }

  /// Log expense deletion
  Future<void> logExpenseDeleted(String description, double amount) async {
    await _createLog(
      message: 'Expense deleted: $description (\$${amount.toStringAsFixed(2)})',
      category: 'expenseManagement',
      type: 'Expense Management',
      additionalData: {
        'action': 'delete',
        'expense_description': description,
        'expense_amount': amount,
      },
    );
  }

  // ============================================================================
  // SECURITY EVENTS
  // ============================================================================

  /// Log unauthorized access attempts
  Future<void> logUnauthorizedAccess(
    String attemptedAction,
    String userRole,
  ) async {
    await _createLog(
      message:
          'SECURITY: Unauthorized access attempt - $attemptedAction by $userRole',
      category: 'security',
      type: 'Security',
      additionalData: {
        'action': 'unauthorized_access',
        'attempted_action': attemptedAction,
        'user_role': userRole,
        'severity': 'warning',
      },
    );
  }

  /// Log suspicious activity
  Future<void> logSuspiciousActivity(
    String description,
    Map<String, dynamic>? details,
  ) async {
    await _createLog(
      message: 'SECURITY: Suspicious activity detected - $description',
      category: 'security',
      type: 'Security',
      additionalData: {
        'action': 'suspicious_activity',
        'description': description,
        'severity': 'warning',
        if (details != null) ...details,
      },
    );
  }

  // ============================================================================
  // UTILITY METHODS
  // ============================================================================

  /// Create a test log entry (for debugging)
  Future<void> createTestLog({String? customMessage}) async {
    final message =
        customMessage ?? 'Test log entry created at ${DateTime.now()}';
    await _createLog(
      message: message,
      category: 'system',
      type: 'System',
      additionalData: {
        'action': 'test',
        'test_timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Clear user context (call when user logs out)
  void clearUserContext() {
    _cachedUserContext = null;
    _lastUserContextUpdate = null;
  }

  /// Get log statistics (for testing)
  Future<Map<String, dynamic>> getLogStats() async {
    try {
      final context = await _getCurrentContext();
      final companyId = context['company_id'];

      if (companyId == null) return {'error': 'No company ID'};

      final snapshot =
          await _firestore
              .collection('logs')
              .where('company_id', isEqualTo: companyId)
              .get();

      // Count by category
      Map<String, int> categoryCount = {};
      for (var doc in snapshot.docs) {
        final category = doc.data()['category'] ?? 'unknown';
        categoryCount[category] = (categoryCount[category] ?? 0) + 1;
      }

      return {
        'total_logs': snapshot.docs.length,
        'by_category': categoryCount,
        'company_id': companyId,
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }
}

/// Extension to add simplified logging to services
extension ServiceLogger on Object {
  AppLogger get logger => AppLogger();
}

/// Mixin for widgets that need logging (simplified)
mixin LoggerMixin {
  AppLogger get logger => AppLogger();

  /// Log major user actions only
  void logMajorUserAction(String action, {Map<String, dynamic>? data}) {
    // Only log if it's a major action (CRUD operations)
    if (_isMajorAction(action)) {
      logger._createLog(
        message: '${runtimeType}: $action',
        category: 'userAction',
        type: 'User Action',
        additionalData: data,
      );
    }
  }

  bool _isMajorAction(String action) {
    const majorActions = [
      'create',
      'created',
      'add',
      'added',
      'update',
      'updated',
      'edit',
      'edited',
      'modify',
      'modified',
      'delete',
      'deleted',
      'remove',
      'removed',
      'approve',
      'approved',
      'reject',
      'rejected',
      'submit',
      'submitted',
      'save',
      'saved',
    ];

    final actionLower = action.toLowerCase();
    return majorActions.any((major) => actionLower.contains(major));
  }
}
