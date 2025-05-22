// lib/services/app_logger.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../utils/uuid_generator.dart';

enum LogLevel { debug, info, warning, error, critical }

enum LogCategory {
  authentication,
  accountManagement,
  budgetManagement,
  expenseManagement,
  system,
  userAction,
  error,
  performance,
  security,
}

class LogContext {
  final String? userId;
  final String? companyId;
  final String? userName;
  final String? userRole;
  final String? userEmail;
  final String? ipAddress;
  final String? userAgent;
  final Map<String, dynamic>? additionalData;

  LogContext({
    this.userId,
    this.companyId,
    this.userName,
    this.userRole,
    this.userEmail,
    this.ipAddress,
    this.userAgent,
    this.additionalData,
  });

  Map<String, dynamic> toMap() {
    return {
      if (userId != null) 'user_id': userId,
      if (companyId != null) 'company_id': companyId,
      if (userName != null) 'user_name': userName,
      if (userRole != null) 'user_role': userRole,
      if (userEmail != null) 'user_email': userEmail,
      if (ipAddress != null) 'ip_address': ipAddress,
      if (userAgent != null) 'user_agent': userAgent,
      if (additionalData != null) ...additionalData!,
    };
  }
}

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

  // App version - you can get this from package_info_plus if needed
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
  Future<LogContext> _getCurrentContext({LogContext? additionalContext}) async {
    // Check if cache is expired or empty
    if (_cachedUserContext == null ||
        _lastUserContextUpdate == null ||
        DateTime.now().difference(_lastUserContextUpdate!) >
            _contextCacheTimeout) {
      await _loadUserContext();
    }

    return LogContext(
      userId: additionalContext?.userId ?? _cachedUserContext?['user_id'],
      companyId:
          additionalContext?.companyId ?? _cachedUserContext?['company_id'],
      userName: additionalContext?.userName ?? _cachedUserContext?['user_name'],
      userRole: additionalContext?.userRole ?? _cachedUserContext?['user_role'],
      userEmail:
          additionalContext?.userEmail ?? _cachedUserContext?['user_email'],
      ipAddress: additionalContext?.ipAddress,
      userAgent: additionalContext?.userAgent,
      additionalData: additionalContext?.additionalData,
    );
  }

  /// Main logging method
  Future<void> log({
    required String message,
    required LogLevel level,
    required LogCategory category,
    LogContext? context,
    Map<String, dynamic>? data,
    String? stackTrace,
    String? errorCode,
  }) async {
    try {
      final logContext = await _getCurrentContext(additionalContext: context);

      final logEntry = {
        'log_id': UuidGenerator.generateUuid(),
        'message': message,
        'level': level.name,
        'category': category.name,
        'timestamp': FieldValue.serverTimestamp(),
        'created_at':
            FieldValue.serverTimestamp(), // For compatibility with existing code
        'log_desc': message, // For compatibility with existing code
        'type': _mapCategoryToType(
          category,
        ), // For compatibility with existing code
        ...logContext.toMap(),
        if (data != null) 'data': data,
        if (stackTrace != null) 'stack_trace': stackTrace,
        if (errorCode != null) 'error_code': errorCode,
        'client_timestamp': DateTime.now().toIso8601String(),
        'app_version': _appVersion,
        'platform': kIsWeb ? 'web' : 'mobile',
      };

      // Store in Firestore
      await _firestore.collection('logs').add(logEntry);

      // Also log to console in debug mode
      if (kDebugMode) {
        _logToConsole(level, category, message, data);
      }
    } catch (e) {
      // Fallback logging to console if Firestore fails
      if (kDebugMode) {
        print('Failed to log to Firestore: $e');
        _logToConsole(level, category, message, data);
      }
    }
  }

  void _logToConsole(
    LogLevel level,
    LogCategory category,
    String message,
    Map<String, dynamic>? data,
  ) {
    final timestamp = DateTime.now().toIso8601String();
    final emoji = _getEmojiForLevel(level);
    final dataStr = data != null ? ' | Data: ${data.toString()}' : '';
    print(
      '$emoji [$timestamp] [${level.name.toUpperCase()}] [${category.name}] $message$dataStr',
    );
  }

  String _getEmojiForLevel(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return '🔍';
      case LogLevel.info:
        return 'ℹ️';
      case LogLevel.warning:
        return '⚠️';
      case LogLevel.error:
        return '❌';
      case LogLevel.critical:
        return '🚨';
    }
  }

  String _mapCategoryToType(LogCategory category) {
    switch (category) {
      case LogCategory.authentication:
        return 'Authentication';
      case LogCategory.accountManagement:
        return 'Account Management';
      case LogCategory.budgetManagement:
        return 'Budget Management';
      case LogCategory.expenseManagement:
        return 'Expense Management';
      case LogCategory.system:
      case LogCategory.performance:
      case LogCategory.security:
        return 'System';
      case LogCategory.userAction:
        return 'User Action';
      case LogCategory.error:
        return 'Error';
    }
  }

  /// Convenience methods for different log levels
  Future<void> debug(
    String message, {
    LogCategory? category,
    LogContext? context,
    Map<String, dynamic>? data,
  }) async {
    await log(
      message: message,
      level: LogLevel.debug,
      category: category ?? LogCategory.system,
      context: context,
      data: data,
    );
  }

  Future<void> info(
    String message, {
    LogCategory? category,
    LogContext? context,
    Map<String, dynamic>? data,
  }) async {
    await log(
      message: message,
      level: LogLevel.info,
      category: category ?? LogCategory.system,
      context: context,
      data: data,
    );
  }

  Future<void> warning(
    String message, {
    LogCategory? category,
    LogContext? context,
    Map<String, dynamic>? data,
  }) async {
    await log(
      message: message,
      level: LogLevel.warning,
      category: category ?? LogCategory.system,
      context: context,
      data: data,
    );
  }

  Future<void> error(
    String message, {
    LogCategory? category,
    LogContext? context,
    Map<String, dynamic>? data,
    dynamic error,
    String? stackTrace,
  }) async {
    Map<String, dynamic> errorData = data ?? {};

    if (error != null) {
      errorData['error_details'] = error.toString();
    }

    await log(
      message: message,
      level: LogLevel.error,
      category: category ?? LogCategory.error,
      context: context,
      data: errorData,
      stackTrace:
          stackTrace ?? (error is Error ? error.stackTrace?.toString() : null),
    );
  }

  Future<void> critical(
    String message, {
    LogCategory? category,
    LogContext? context,
    Map<String, dynamic>? data,
    dynamic error,
    String? stackTrace,
  }) async {
    Map<String, dynamic> errorData = data ?? {};

    if (error != null) {
      errorData['error_details'] = error.toString();
    }

    await log(
      message: message,
      level: LogLevel.critical,
      category: category ?? LogCategory.error,
      context: context,
      data: errorData,
      stackTrace:
          stackTrace ?? (error is Error ? error.stackTrace?.toString() : null),
    );
  }

  /// Specific logging methods for common scenarios
  Future<void> logUserAction(
    String action, {
    Map<String, dynamic>? data,
    LogContext? context,
  }) async {
    await info(
      'User action: $action',
      category: LogCategory.userAction,
      context: context,
      data: data,
    );
  }

  Future<void> logAuthentication(
    String action, {
    bool success = true,
    String? email,
    Map<String, dynamic>? data,
  }) async {
    await info(
      'Authentication: $action${success ? ' successful' : ' failed'}${email != null ? ' for $email' : ''}',
      category: LogCategory.authentication,
      data: {'success': success, if (email != null) 'email': email, ...?data},
    );
  }

  Future<void> logAccountManagement(
    String action, {
    String? targetUserId,
    String? targetEmail,
    Map<String, dynamic>? data,
  }) async {
    await info(
      'Account management: $action${targetEmail != null ? ' for $targetEmail' : ''}',
      category: LogCategory.accountManagement,
      data: {
        if (targetUserId != null) 'target_user_id': targetUserId,
        if (targetEmail != null) 'target_email': targetEmail,
        ...?data,
      },
    );
  }

  Future<void> logBudgetManagement(
    String action, {
    String? budgetId,
    String? budgetName,
    double? amount,
    Map<String, dynamic>? data,
  }) async {
    await info(
      'Budget management: $action${budgetName != null ? ' - $budgetName' : ''}',
      category: LogCategory.budgetManagement,
      data: {
        if (budgetId != null) 'budget_id': budgetId,
        if (budgetName != null) 'budget_name': budgetName,
        if (amount != null) 'amount': amount,
        ...?data,
      },
    );
  }

  Future<void> logExpenseManagement(
    String action, {
    String? expenseId,
    String? description,
    double? amount,
    Map<String, dynamic>? data,
  }) async {
    await info(
      'Expense management: $action${description != null ? ' - $description' : ''}',
      category: LogCategory.expenseManagement,
      data: {
        if (expenseId != null) 'expense_id': expenseId,
        if (description != null) 'description': description,
        if (amount != null) 'amount': amount,
        ...?data,
      },
    );
  }

  Future<void> logSecurity(
    String event, {
    LogLevel level = LogLevel.warning,
    Map<String, dynamic>? data,
  }) async {
    await log(
      message: 'Security event: $event',
      level: level,
      category: LogCategory.security,
      data: data,
    );
  }

  Future<void> logPerformance(
    String operation, {
    required Duration duration,
    Map<String, dynamic>? data,
  }) async {
    await info(
      'Performance: $operation completed in ${duration.inMilliseconds}ms',
      category: LogCategory.performance,
      data: {
        'operation': operation,
        'duration_ms': duration.inMilliseconds,
        ...?data,
      },
    );
  }

  /// Helper method to time operations
  Future<T> timeOperation<T>(
    String operationName,
    Future<T> Function() operation, {
    Map<String, dynamic>? data,
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      final result = await operation();
      stopwatch.stop();
      await logPerformance(
        operationName,
        duration: stopwatch.elapsed,
        data: data,
      );
      return result;
    } catch (e) {
      stopwatch.stop();
      await error(
        'Operation failed: $operationName',
        category: LogCategory.performance,
        error: e,
        data: {
          'operation': operationName,
          'duration_ms': stopwatch.elapsed.inMilliseconds,
          ...?data,
        },
      );
      rethrow;
    }
  }

  /// Clear user context (call when user logs out)
  void clearUserContext() {
    _cachedUserContext = null;
    _lastUserContextUpdate = null;
  }

  /// Method to clean up old logs (call periodically)
  Future<void> cleanupOldLogs({int daysToKeep = 90}) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));
      final cutoffTimestamp = Timestamp.fromDate(cutoffDate);

      final oldLogs =
          await _firestore
              .collection('logs')
              .where('timestamp', isLessThan: cutoffTimestamp)
              .limit(500) // Process in batches
              .get();

      if (oldLogs.docs.isNotEmpty) {
        final batch = _firestore.batch();
        for (var doc in oldLogs.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();

        await info(
          'Log cleanup: Deleted ${oldLogs.docs.length} old log entries',
          category: LogCategory.system,
          data: {
            'deleted_count': oldLogs.docs.length,
            'cutoff_date': cutoffDate.toIso8601String(),
          },
        );
      }
    } catch (e) {
      await error(
        'Failed to cleanup old logs',
        error: e,
        category: LogCategory.system,
      );
    }
  }
}

/// Extension to add logging to existing services
extension ServiceLogger on Object {
  AppLogger get logger => AppLogger();
}

/// Mixin for widgets that need logging
mixin LoggerMixin {
  AppLogger get logger => AppLogger();

  void logWidgetAction(String action, {Map<String, dynamic>? data}) {
    logger.logUserAction('${runtimeType}: $action', data: data);
  }

  void logWidgetError(String message, {dynamic error, String? stackTrace}) {
    logger.error(
      '${runtimeType}: $message',
      error: error,
      stackTrace: stackTrace,
      category: LogCategory.userAction,
    );
  }
}
