import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service for reading and managing logs created by AppLogger
/// This service focuses on admin dashboard functionality and log analytics
class FirebaseLogsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user ID
  String? get _currentUserId => _auth.currentUser?.uid;

  // Get logs for admin (filtered by company)
  Future<List<Map<String, dynamic>>> getLogsForAdmin({
    String? filterCategory,
    String? filterLevel,
    int limit = 50,
    DocumentSnapshot? lastDocument,
  }) async {
    try {
      if (_currentUserId == null) return [];

      // Verify user is admin
      final userDoc = await _firestore.collection('accounts').doc(_currentUserId).get();
      if (!userDoc.exists || userDoc.data()!['role'] != 'Administrator') {
        throw 'Only administrators can view logs';
      }

      final companyId = userDoc.data()!['company_id'];

      List<Map<String, dynamic>> logs = [];

      // Strategy 1: Try the ideal query first
      try {
        Query query = _firestore
            .collection('logs')
            .where('company_id', isEqualTo: companyId)
            .orderBy('created_at', descending: true);

        // Add category filter if specified
        if (filterCategory != null && filterCategory != 'All') {
          query = query.where('type', isEqualTo: filterCategory);
        }

        // Add pagination
        if (lastDocument != null) {
          query = query.startAfterDocument(lastDocument);
        }

        query = query.limit(limit);

        // Execute query
        final snapshot = await query.get();
        logs = await _processLogDocuments(snapshot.docs);
        
      } catch (e) {
        // Strategy 2: Simple company filter without orderBy
        try {
          final snapshot = await _firestore
              .collection('logs')
              .where('company_id', isEqualTo: companyId)
              .limit(limit)
              .get();
          
          logs = await _processLogDocuments(snapshot.docs);
          
          // Apply filters and sorting in memory
          if (filterCategory != null && filterCategory != 'All') {
            logs = logs.where((log) => log['type'] == filterCategory).toList();
          }
          
          // Sort by created_at in memory
          logs.sort((a, b) {
            final aTime = a['created_at'] as Timestamp?;
            final bTime = b['created_at'] as Timestamp?;
            if (aTime == null || bTime == null) return 0;
            return bTime.compareTo(aTime);
          });
          
        } catch (e2) {
          // Strategy 3: Get all logs and filter in memory (last resort)
          final snapshot = await _firestore
              .collection('logs')
              .limit(200) // Reasonable limit for memory filtering
              .get();
          
          final allLogs = await _processLogDocuments(snapshot.docs);
          
          // Filter by company in memory
          logs = allLogs.where((log) => log['company_id'] == companyId).toList();
          
          // Apply category filter
          if (filterCategory != null && filterCategory != 'All') {
            logs = logs.where((log) => log['type'] == filterCategory).toList();
          }
          
          // Sort by created_at
          logs.sort((a, b) {
            final aTime = a['created_at'] as Timestamp?;
            final bTime = b['created_at'] as Timestamp?;
            if (aTime == null || bTime == null) return 0;
            return bTime.compareTo(aTime);
          });
          
          // Apply limit
          if (logs.length > limit) {
            logs = logs.take(limit).toList();
          }
        }
      }

      return logs;
    } catch (e) {
      return [];
    }
  }

  // Get logs by category
  Future<List<Map<String, dynamic>>> getLogsByCategory(
    String category, {
    int limit = 50,
  }) async {
    try {
      if (_currentUserId == null) return [];

      // Verify user is admin
      final userDoc = await _firestore.collection('accounts').doc(_currentUserId).get();
      if (!userDoc.exists || userDoc.data()!['role'] != 'Administrator') {
        throw 'Only administrators can view logs';
      }

      final companyId = userDoc.data()!['company_id'];

      final snapshot = await _firestore
          .collection('logs')
          .where('company_id', isEqualTo: companyId)
          .where('category', isEqualTo: category)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      final logs = await _processLogDocuments(snapshot.docs);
      return logs;
    } catch (e) {
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
      final userDoc = await _firestore.collection('accounts').doc(_currentUserId).get();
      if (!userDoc.exists || userDoc.data()!['role'] != 'Administrator') {
        throw 'Only administrators can search logs';
      }

      final companyId = userDoc.data()!['company_id'];

      // For basic search, we'll get logs and filter client-side
      final snapshot = await _firestore
          .collection('logs')
          .where('company_id', isEqualTo: companyId)
          .orderBy('timestamp', descending: true)
          .limit(limit * 2) // Get more docs to account for filtering
          .get();

      final allLogs = await _processLogDocuments(snapshot.docs);

      // Filter by search term
      final searchTermLower = searchTerm.toLowerCase();
      final filteredLogs = allLogs.where((log) {
        final message = (log['message'] ?? '').toString().toLowerCase();
        final userName = (log['user_name'] ?? '').toString().toLowerCase();
        final userEmail = (log['user_email'] ?? '').toString().toLowerCase();
        final category = (log['category'] ?? '').toString().toLowerCase();

        return message.contains(searchTermLower) ||
            userName.contains(searchTermLower) ||
            userEmail.contains(searchTermLower) ||
            category.contains(searchTermLower);
      }).take(limit).toList();

      return filteredLogs;
    } catch (e) {
      return [];
    }
  }

  // Get logs for a specific date range
  Future<List<Map<String, dynamic>>> getLogsByDateRange({
    required DateTime startDate,
    required DateTime endDate,
    String? filterCategory,
    String? filterLevel,
    int limit = 100,
  }) async {
    try {
      if (_currentUserId == null) return [];

      // Verify user is admin
      final userDoc = await _firestore.collection('accounts').doc(_currentUserId).get();
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
          .where('timestamp', isGreaterThanOrEqualTo: startTimestamp)
          .where('timestamp', isLessThanOrEqualTo: endTimestamp)
          .orderBy('timestamp', descending: true);

      // Add category filter if specified
      if (filterCategory != null) {
        query = query.where('category', isEqualTo: filterCategory);
      }

      query = query.limit(limit);

      final snapshot = await query.get();
      final logs = await _processLogDocuments(snapshot.docs);

      return logs;
    } catch (e) {
      return [];
    }
  }

  // Get activity summary (counts by category and level)
  Future<Map<String, dynamic>> getActivitySummary({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      if (_currentUserId == null) return {};

      // Verify user is admin
      final userDoc = await _firestore.collection('accounts').doc(_currentUserId).get();
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
            .where('timestamp', isGreaterThanOrEqualTo: startTimestamp)
            .where('timestamp', isLessThanOrEqualTo: endTimestamp);
      }

      final snapshot = await query.get();

      // Initialize counters
      Map<String, int> categoryCount = {};
      Map<String, int> levelCount = {};
      int totalLogs = snapshot.docs.length;

      // Count by category and level
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;

        final category = data['category'] ?? 'unknown';
        final level = data['level'] ?? 'unknown';

        categoryCount[category] = (categoryCount[category] ?? 0) + 1;
        levelCount[level] = (levelCount[level] ?? 0) + 1;
      }

      final summary = {
        'total_logs': totalLogs,
        'by_category': categoryCount,
        'by_level': levelCount,
        'date_range': {
          'start': startDate?.toIso8601String(),
          'end': endDate?.toIso8601String(),
        },
        'company_id': companyId,
      };

      return summary;
    } catch (e) {
      return {};
    }
  }

  // Export logs to CSV format (returns data that can be converted to CSV)
  Future<List<Map<String, dynamic>>> getLogsForExport({
    String? filterCategory,
    String? filterLevel,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      if (_currentUserId == null) return [];

      // Verify user is admin
      final userDoc = await _firestore.collection('accounts').doc(_currentUserId).get();
      if (!userDoc.exists || userDoc.data()!['role'] != 'Administrator') {
        throw 'Only administrators can export logs';
      }

      final companyId = userDoc.data()!['company_id'];

      // Build query
      Query query = _firestore
          .collection('logs')
          .where('company_id', isEqualTo: companyId)
          .orderBy('timestamp', descending: true);

      // Add category filter
      if (filterCategory != null) {
        query = query.where('category', isEqualTo: filterCategory);
      }

      // Add date range
      if (startDate != null && endDate != null) {
        final startTimestamp = Timestamp.fromDate(startDate);
        final endTimestamp = Timestamp.fromDate(endDate);
        query = query
            .where('timestamp', isGreaterThanOrEqualTo: startTimestamp)
            .where('timestamp', isLessThanOrEqualTo: endTimestamp);
      }

      // Get all matching logs (no limit for export)
      final snapshot = await query.get();
      final logs = await _processLogDocuments(snapshot.docs);

      // Format for CSV export
      final exportData = logs.map((log) => {
        'Timestamp': _formatTimestamp(log['timestamp']),
        'Level': log['level'] ?? 'N/A',
        'Category': log['category'] ?? 'N/A',
        'Message': log['message'] ?? 'N/A',
        'User': log['user_name'] ?? 'N/A',
        'Email': log['user_email'] ?? 'N/A',
        'Role': log['user_role'] ?? 'N/A',
        'Company ID': log['company_id'] ?? 'N/A',
      }).toList();

      return exportData;
    } catch (e) {
      return [];
    }
  }

  // Get available log categories
  static List<String> getLogCategories() {
    return [
      'All',
      'authentication',
      'accountManagement',
      'budgetManagement',
      'expenseManagement',
      'system',
      'userAction',
      'error',
      'performance',
      'security',
    ];
  }

  // Get available log levels
  static List<String> getLogLevels() {
    return ['All', 'debug', 'info', 'warning', 'error', 'critical'];
  }

  // Process log documents with user information
  Future<List<Map<String, dynamic>>> _processLogDocuments(
    List<QueryDocumentSnapshot> docs,
  ) async {
    List<Map<String, dynamic>> logs = [];

    for (var doc in docs) {
      try {
        final logData = doc.data() as Map<String, dynamic>;
        logData['document_id'] = doc.id;

        // Map field names for compatibility
        logData['category'] = logData['type'] ?? logData['category'] ?? 'unknown';
        logData['message'] = logData['log_desc'] ?? logData['message'] ?? 'No message';
        logData['timestamp'] = logData['created_at'] ?? logData['timestamp'];
        logData['level'] = logData['level'] ?? 'info';

        // Get user information if user_id exists
        if (logData['user_id'] != null) {
          try {
            final userDoc = await _firestore
                .collection('accounts')
                .doc(logData['user_id'])
                .get();
            if (userDoc.exists) {
              final userData = userDoc.data()!;
              logData['user_name'] = '${userData['f_name']} ${userData['l_name']}';
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
      } catch (e) {
        // Continue with other logs
      }
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

  // Method to manually test database connection and structure
  Future<Map<String, dynamic>> testDatabaseStructure() async {
    try {
      // Test 1: Check if logs collection exists and get count
      final logsSnapshot = await _firestore.collection('logs').get();
      
      // Test 2: Get current user info
      final userDoc = await _firestore.collection('accounts').doc(_currentUserId).get();
      final userData = userDoc.exists ? userDoc.data() : null;
      
      // Test 3: Check logs by company if user exists
      List<Map<String, dynamic>> companyLogs = [];
      if (userData != null) {
        final companyId = userData['company_id'];
        final companyLogsSnapshot = await _firestore
            .collection('logs')
            .where('company_id', isEqualTo: companyId)
            .get();
        companyLogs = companyLogsSnapshot.docs.map((doc) => doc.data()).toList();
      }
      
      // Test 4: Get sample log structure
      Map<String, dynamic> sampleLog = {};
      if (logsSnapshot.docs.isNotEmpty) {
        sampleLog = logsSnapshot.docs.first.data();
      }
      
      final result = {
        'total_logs': logsSnapshot.docs.length,
        'current_user_id': _currentUserId,
        'user_data': userData,
        'company_logs_count': companyLogs.length,
        'sample_log_structure': sampleLog.keys.toList(),
        'sample_log_data': sampleLog,
        'company_logs_sample': companyLogs.take(3).toList(),
      };
      
      return result;
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  // Method to create a test log entry
  Future<bool> createTestLog() async {
    try {
      if (_currentUserId == null) return false;
      
      final userDoc = await _firestore.collection('accounts').doc(_currentUserId).get();
      if (!userDoc.exists) return false;
      
      final userData = userDoc.data()!;
      final companyId = userData['company_id'];
      
      // Create a test log entry
      await _firestore.collection('logs').add({
        'log_id': 'test_${DateTime.now().millisecondsSinceEpoch}',
        'message': 'Test log entry created manually',
        'log_desc': 'Test log entry created manually',
        'level': 'info',
        'category': 'system',
        'type': 'System',
        'timestamp': FieldValue.serverTimestamp(),
        'created_at': FieldValue.serverTimestamp(),
        'user_id': _currentUserId,
        'company_id': companyId,
        'user_name': '${userData['f_name']} ${userData['l_name']}',
        'user_email': userData['email'],
        'user_role': userData['role'],
        'client_timestamp': DateTime.now().toIso8601String(),
        'app_version': '1.0.0',
        'platform': 'web',
      });
      
      return true;
    } catch (e) {
      return false;
    }
  }
}