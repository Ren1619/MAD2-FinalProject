import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/uuid_generator.dart';

class FirebaseLogsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Log type constants
  static const String TYPE_AUTHENTICATION = 'Authentication';
  static const String TYPE_ACCOUNT_MANAGEMENT = 'Account Management';
  static const String TYPE_BUDGET_MANAGEMENT = 'Budget Management';
  static const String TYPE_EXPENSE_MANAGEMENT = 'Expense Management';
  static const String TYPE_SYSTEM = 'System';

  // Get current user ID
  String? get _currentUserId => _auth.currentUser?.uid;

  // Log an activity
  Future<void> logActivity({
    required String description,
    required String type,
    String? companyId,
    String? userId,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      // If companyId is not provided, get it from current user
      String? finalCompanyId = companyId;
      String? finalUserId = userId ?? _currentUserId;

      if (finalCompanyId == null && finalUserId != null) {
        final userDoc =
            await _firestore.collection('accounts').doc(finalUserId).get();
        if (userDoc.exists) {
          finalCompanyId = userDoc.data()!['company_id'];
        }
      }

      // Create log entry
      Map<String, dynamic> logData = {
        'log_id': UuidGenerator.generateUuid(),
        'log_desc': description,
        'type': type,
        'company_id': finalCompanyId,
        'user_id': finalUserId,
        'created_at': FieldValue.serverTimestamp(),
      };

      // Add any additional data
      if (additionalData != null) {
        logData.addAll(additionalData);
      }

      await _firestore.collection('logs').add(logData);
    } catch (e) {
      print('Error logging activity: $e');
      // Don't throw error for logging failures to avoid breaking main operations
    }
  }

  // Get logs for admin (filtered by company)
  Future<List<Map<String, dynamic>>> getLogsForAdmin({
    String? filterType,
    int limit = 50,
    DocumentSnapshot? lastDocument,
  }) async {
    try {
      if (_currentUserId == null) return [];

      // Verify user is admin
      final userDoc =
          await _firestore.collection('accounts').doc(_currentUserId).get();
      if (!userDoc.exists || userDoc.data()!['role'] != 'Administrator') {
        throw 'Only administrators can view logs';
      }

      final companyId = userDoc.data()!['company_id'];

      // Build query
      Query query = _firestore
          .collection('logs')
          .where('company_id', isEqualTo: companyId)
          .orderBy('created_at', descending: true);

      // Add type filter if specified
      if (filterType != null && filterType != 'All') {
        query = query.where('type', isEqualTo: filterType);
      }

      // Add pagination
      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      query = query.limit(limit);

      // Execute query
      final snapshot = await query.get();

      // Process logs and add user information
      List<Map<String, dynamic>> logs = [];
      for (var doc in snapshot.docs) {
        final logData = doc.data() as Map<String, dynamic>;
        logData['document_id'] = doc.id; // For pagination

        // Get user information if user_id exists
        if (logData['user_id'] != null) {
          try {
            final userSnapshot =
                await _firestore
                    .collection('accounts')
                    .doc(logData['user_id'])
                    .get();

            if (userSnapshot.exists) {
              final userData = userSnapshot.data()!;
              logData['user_name'] =
                  '${userData['f_name']} ${userData['l_name']}';
              logData['user_email'] = userData['email'];
              logData['user_role'] = userData['role'];
            } else {
              logData['user_name'] = 'Unknown User';
              logData['user_email'] = 'N/A';
              logData['user_role'] = 'N/A';
            }
          } catch (e) {
            logData['user_name'] = 'Unknown User';
            logData['user_email'] = 'N/A';
            logData['user_role'] = 'N/A';
          }
        } else {
          logData['user_name'] = 'System';
          logData['user_email'] = 'N/A';
          logData['user_role'] = 'System';
        }

        logs.add(logData);
      }

      return logs;
    } catch (e) {
      print('Error getting logs for admin: $e');
      return [];
    }
  }

  // Get logs by type
  Future<List<Map<String, dynamic>>> getLogsByType(
    String type, {
    int limit = 50,
  }) async {
    try {
      if (_currentUserId == null) return [];

      // Verify user is admin
      final userDoc =
          await _firestore.collection('accounts').doc(_currentUserId).get();
      if (!userDoc.exists || userDoc.data()!['role'] != 'Administrator') {
        throw 'Only administrators can view logs';
      }

      final companyId = userDoc.data()!['company_id'];

      final snapshot =
          await _firestore
              .collection('logs')
              .where('company_id', isEqualTo: companyId)
              .where('type', isEqualTo: type)
              .orderBy('created_at', descending: true)
              .limit(limit)
              .get();

      return _processLogDocuments(snapshot.docs);
    } catch (e) {
      print('Error getting logs by type: $e');
      return [];
    }
  }

  // Search logs by description
  Future<List<Map<String, dynamic>>> searchLogs(
    String searchTerm, {
    int limit = 50,
  }) async {
    try {
      if (_currentUserId == null) return [];

      // Verify user is admin
      final userDoc =
          await _firestore.collection('accounts').doc(_currentUserId).get();
      if (!userDoc.exists || userDoc.data()!['role'] != 'Administrator') {
        throw 'Only administrators can view logs';
      }

      final companyId = userDoc.data()!['company_id'];

      // For basic search, we'll get all logs and filter client-side
      // In a production app, you might want to use a proper search service
      final snapshot =
          await _firestore
              .collection('logs')
              .where('company_id', isEqualTo: companyId)
              .orderBy('created_at', descending: true)
              .limit(limit * 2) // Get more docs to account for filtering
              .get();

      final allLogs = await _processLogDocuments(snapshot.docs);

      // Filter by search term
      final searchTermLower = searchTerm.toLowerCase();
      return allLogs
          .where((log) {
            final description =
                (log['log_desc'] ?? '').toString().toLowerCase();
            final userName = (log['user_name'] ?? '').toString().toLowerCase();
            final userEmail =
                (log['user_email'] ?? '').toString().toLowerCase();

            return description.contains(searchTermLower) ||
                userName.contains(searchTermLower) ||
                userEmail.contains(searchTermLower);
          })
          .take(limit)
          .toList();
    } catch (e) {
      print('Error searching logs: $e');
      return [];
    }
  }

  // Get logs for a specific date range
  Future<List<Map<String, dynamic>>> getLogsByDateRange({
    required DateTime startDate,
    required DateTime endDate,
    String? filterType,
    int limit = 100,
  }) async {
    try {
      if (_currentUserId == null) return [];

      // Verify user is admin
      final userDoc =
          await _firestore.collection('accounts').doc(_currentUserId).get();
      if (!userDoc.exists || userDoc.data()!['role'] != 'Administrator') {
        throw 'Only administrators can view logs';
      }

      final companyId = userDoc.data()!['company_id'];

      // Convert dates to Firestore timestamps
      final startTimestamp = Timestamp.fromDate(startDate);
      final endTimestamp = Timestamp.fromDate(endDate);

      // Build query
      Query query = _firestore
          .collection('logs')
          .where('company_id', isEqualTo: companyId)
          .where('created_at', isGreaterThanOrEqualTo: startTimestamp)
          .where('created_at', isLessThanOrEqualTo: endTimestamp)
          .orderBy('created_at', descending: true);

      // Add type filter if specified
      if (filterType != null && filterType != 'All') {
        query = query.where('type', isEqualTo: filterType);
      }

      query = query.limit(limit);

      final snapshot = await query.get();
      return _processLogDocuments(snapshot.docs);
    } catch (e) {
      print('Error getting logs by date range: $e');
      return [];
    }
  }

  // Get activity summary (counts by type)
  Future<Map<String, int>> getActivitySummary({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      if (_currentUserId == null) return {};

      // Verify user is admin
      final userDoc =
          await _firestore.collection('accounts').doc(_currentUserId).get();
      if (!userDoc.exists || userDoc.data()!['role'] != 'Administrator') {
        throw 'Only administrators can view activity summary';
      }

      final companyId = userDoc.data()!['company_id'];

      // Build base query
      Query query = _firestore
          .collection('logs')
          .where('company_id', isEqualTo: companyId);

      // Add date range if specified
      if (startDate != null && endDate != null) {
        final startTimestamp = Timestamp.fromDate(startDate);
        final endTimestamp = Timestamp.fromDate(endDate);
        query = query
            .where('created_at', isGreaterThanOrEqualTo: startTimestamp)
            .where('created_at', isLessThanOrEqualTo: endTimestamp);
      }

      final snapshot = await query.get();

      // Count by type
      Map<String, int> summary = {
        TYPE_AUTHENTICATION: 0,
        TYPE_ACCOUNT_MANAGEMENT: 0,
        TYPE_BUDGET_MANAGEMENT: 0,
        TYPE_EXPENSE_MANAGEMENT: 0,
        TYPE_SYSTEM: 0,
      };

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final type = data['type'] ?? 'Unknown';
        summary[type] = (summary[type] ?? 0) + 1;
      }

      return summary;
    } catch (e) {
      print('Error getting activity summary: $e');
      return {};
    }
  }

  // Export logs to CSV format (returns data that can be converted to CSV)
  Future<List<Map<String, dynamic>>> getLogsForExport({
    String? filterType,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      if (_currentUserId == null) return [];

      // Verify user is admin
      final userDoc =
          await _firestore.collection('accounts').doc(_currentUserId).get();
      if (!userDoc.exists || userDoc.data()!['role'] != 'Administrator') {
        throw 'Only administrators can export logs';
      }

      final companyId = userDoc.data()!['company_id'];

      // Build query
      Query query = _firestore
          .collection('logs')
          .where('company_id', isEqualTo: companyId)
          .orderBy('created_at', descending: true);

      // Add type filter
      if (filterType != null && filterType != 'All') {
        query = query.where('type', isEqualTo: filterType);
      }

      // Add date range
      if (startDate != null && endDate != null) {
        final startTimestamp = Timestamp.fromDate(startDate);
        final endTimestamp = Timestamp.fromDate(endDate);
        query = query
            .where('created_at', isGreaterThanOrEqualTo: startTimestamp)
            .where('created_at', isLessThanOrEqualTo: endTimestamp);
      }

      // Get all matching logs (no limit for export)
      final snapshot = await query.get();
      final logs = await _processLogDocuments(snapshot.docs);

      // Format for CSV export
      return logs
          .map(
            (log) => {
              'Date': _formatTimestamp(log['created_at']),
              'Type': log['type'] ?? 'N/A',
              'Description': log['log_desc'] ?? 'N/A',
              'User': log['user_name'] ?? 'N/A',
              'Email': log['user_email'] ?? 'N/A',
              'Role': log['user_role'] ?? 'N/A',
            },
          )
          .toList();
    } catch (e) {
      print('Error getting logs for export: $e');
      return [];
    }
  }

  // Delete old logs (cleanup function)
  Future<bool> deleteOldLogs(int daysToKeep) async {
    try {
      if (_currentUserId == null) return false;

      // Verify user is admin
      final userDoc =
          await _firestore.collection('accounts').doc(_currentUserId).get();
      if (!userDoc.exists || userDoc.data()!['role'] != 'Administrator') {
        throw 'Only administrators can delete logs';
      }

      final companyId = userDoc.data()!['company_id'];
      final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));
      final cutoffTimestamp = Timestamp.fromDate(cutoffDate);

      // Find logs to delete
      final snapshot =
          await _firestore
              .collection('logs')
              .where('company_id', isEqualTo: companyId)
              .where('created_at', isLessThan: cutoffTimestamp)
              .get();

      // Delete in batches (Firestore has a limit of 500 operations per batch)
      final batch = _firestore.batch();
      int count = 0;

      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
        count++;

        // Commit batch if we reach the limit
        if (count >= 500) {
          await batch.commit();
          count = 0;
        }
      }

      // Commit remaining operations
      if (count > 0) {
        await batch.commit();
      }

      // Log the cleanup activity
      await logActivity(
        description:
            'Deleted ${snapshot.docs.length} old log entries (older than $daysToKeep days)',
        type: TYPE_SYSTEM,
        companyId: companyId,
      );

      return true;
    } catch (e) {
      print('Error deleting old logs: $e');
      return false;
    }
  }

  // Get available log types
  static List<String> getLogTypes() {
    return [
      'All',
      TYPE_AUTHENTICATION,
      TYPE_ACCOUNT_MANAGEMENT,
      TYPE_BUDGET_MANAGEMENT,
      TYPE_EXPENSE_MANAGEMENT,
      TYPE_SYSTEM,
    ];
  }

  // Private helper methods
  Future<List<Map<String, dynamic>>> _processLogDocuments(
    List<QueryDocumentSnapshot> docs,
  ) async {
    List<Map<String, dynamic>> logs = [];

    for (var doc in docs) {
      final logData = doc.data() as Map<String, dynamic>;
      logData['document_id'] = doc.id;

      // Get user information if user_id exists
      if (logData['user_id'] != null) {
        try {
          final userDoc =
              await _firestore
                  .collection('accounts')
                  .doc(logData['user_id'])
                  .get();
          if (userDoc.exists) {
            final userData = userDoc.data()!;
            logData['user_name'] =
                '${userData['f_name']} ${userData['l_name']}';
            logData['user_email'] = userData['email'];
            logData['user_role'] = userData['role'];
          } else {
            logData['user_name'] = 'Unknown User';
            logData['user_email'] = 'N/A';
            logData['user_role'] = 'N/A';
          }
        } catch (e) {
          logData['user_name'] = 'Unknown User';
          logData['user_email'] = 'N/A';
          logData['user_role'] = 'N/A';
        }
      } else {
        logData['user_name'] = 'System';
        logData['user_email'] = 'N/A';
        logData['user_role'] = 'System';
      }

      logs.add(logData);
    }

    return logs;
  }

  String _formatTimestamp(dynamic timestamp) {
    try {
      if (timestamp is Timestamp) {
        final date = timestamp.toDate();
        return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
            '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}';
      }
      return timestamp.toString();
    } catch (e) {
      return 'Invalid Date';
    }
  }
}
