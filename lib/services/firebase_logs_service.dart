import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:moneyger_finalproject/services/app_logger.dart';

/// Service for reading, managing, and analyzing logs created by AppLogger
/// This service is focused on admin dashboard functionality and log analytics
class FirebaseLogsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AppLogger _logger = AppLogger();

  // Get current user ID
  String? get _currentUserId => _auth.currentUser?.uid;

  // Get logs for admin (filtered by company)
  Future<List<Map<String, dynamic>>> getLogsForAdmin({
    String? filterCategory,
    String? filterLevel,
    int limit = 50,
    DocumentSnapshot? lastDocument,
  }) async {
    return await _logger.timeOperation(
      'Get Logs for Admin',
      () async {
        try {
          if (_currentUserId == null) {
            await _logger.error(
              'Cannot get logs - no current user ID',
              category: LogCategory.system,
            );
            return [];
          }

          // Verify user is admin
          final userDoc =
              await _firestore.collection('accounts').doc(_currentUserId).get();
          if (!userDoc.exists || userDoc.data()!['role'] != 'Administrator') {
            await _logger.logSecurity(
              'Unauthorized log access attempt',
              level: LogLevel.warning,
              data: {
                'user_id': _currentUserId,
                'attempted_action': 'view_logs',
              },
            );
            throw 'Only administrators can view logs';
          }

          final companyId = userDoc.data()!['company_id'];

          await _logger.debug(
            'Retrieving logs for admin dashboard',
            category: LogCategory.system,
            data: {
              'company_id': companyId,
              'filter_category': filterCategory,
              'filter_level': filterLevel,
              'limit': limit,
              'has_pagination': lastDocument != null,
            },
          );

          // Build query - Updated to use correct field names
          Query query = _firestore
              .collection('logs')
              .where('company_id', isEqualTo: companyId)
              .orderBy(
                'created_at',
                descending: true,
              ); // Changed from 'timestamp' to 'created_at'

          // Add category filter if specified - Updated field name
          if (filterCategory != null && filterCategory != 'All') {
            query = query.where(
              'type',
              isEqualTo: filterCategory,
            ); // Changed from 'category' to 'type'
          }

          // Skip level filter for now since it doesn't exist in your current data
          // You can add it later if you add level field to your logs

          // Add pagination
          if (lastDocument != null) {
            query = query.startAfterDocument(lastDocument);
          }

          query = query.limit(limit);

          // Execute query
          final snapshot = await query.get();

          await _logger.debug(
            'Log query completed',
            category: LogCategory.system,
            data: {'logs_found': snapshot.docs.length, 'company_id': companyId},
          );

          // Process logs and add user information
          final logs = await _processLogDocuments(snapshot.docs);

          await _logger.info(
            'Admin log retrieval completed',
            category: LogCategory.system,
            data: {
              'logs_returned': logs.length,
              'company_id': companyId,
              'admin_user_id': _currentUserId,
            },
          );

          return logs;
        } catch (e) {
          await _logger.error(
            'Failed to get logs for admin',
            category: LogCategory.system,
            error: e,
            data: {
              'filter_category': filterCategory,
              'filter_level': filterLevel,
              'limit': limit,
            },
          );
          return [];
        }
      },
      data: {
        'operation': 'get_logs_for_admin',
        'filter_category': filterCategory,
        'filter_level': filterLevel,
      },
    );
  }

  // Get logs by category (using AppLogger categories)
  Future<List<Map<String, dynamic>>> getLogsByCategory(
    LogCategory category, {
    int limit = 50,
  }) async {
    return await _logger.timeOperation(
      'Get Logs by Category',
      () async {
        try {
          if (_currentUserId == null) {
            await _logger.error(
              'Cannot get logs by category - no current user ID',
              category: LogCategory.system,
            );
            return [];
          }

          // Verify user is admin
          final userDoc =
              await _firestore.collection('accounts').doc(_currentUserId).get();
          if (!userDoc.exists || userDoc.data()!['role'] != 'Administrator') {
            await _logger.logSecurity(
              'Unauthorized log category access attempt',
              level: LogLevel.warning,
              data: {
                'user_id': _currentUserId,
                'requested_category': category.name,
              },
            );
            throw 'Only administrators can view logs';
          }

          final companyId = userDoc.data()!['company_id'];

          await _logger.debug(
            'Getting logs by category',
            category: LogCategory.system,
            data: {
              'requested_category': category.name,
              'company_id': companyId,
              'limit': limit,
            },
          );

          final snapshot =
              await _firestore
                  .collection('logs')
                  .where('company_id', isEqualTo: companyId)
                  .where('category', isEqualTo: category.name)
                  .orderBy('timestamp', descending: true)
                  .limit(limit)
                  .get();

          final logs = await _processLogDocuments(snapshot.docs);

          await _logger.info(
            'Retrieved logs by category',
            category: LogCategory.system,
            data: {
              'requested_category': category.name,
              'logs_found': logs.length,
              'company_id': companyId,
            },
          );

          return logs;
        } catch (e) {
          await _logger.error(
            'Failed to get logs by category',
            category: LogCategory.system,
            error: e,
            data: {'requested_category': category.name},
          );
          return [];
        }
      },
      data: {'operation': 'get_logs_by_category', 'category': category.name},
    );
  }

  // Search logs by description
  Future<List<Map<String, dynamic>>> searchLogs(
    String searchTerm, {
    int limit = 50,
  }) async {
    return await _logger.timeOperation(
      'Search Logs',
      () async {
        try {
          if (_currentUserId == null) {
            await _logger.error(
              'Cannot search logs - no current user ID',
              category: LogCategory.system,
            );
            return [];
          }

          // Verify user is admin
          final userDoc =
              await _firestore.collection('accounts').doc(_currentUserId).get();
          if (!userDoc.exists || userDoc.data()!['role'] != 'Administrator') {
            await _logger.logSecurity(
              'Unauthorized log search attempt',
              level: LogLevel.warning,
              data: {'user_id': _currentUserId, 'search_term': searchTerm},
            );
            throw 'Only administrators can search logs';
          }

          final companyId = userDoc.data()!['company_id'];

          await _logger.debug(
            'Searching logs',
            category: LogCategory.system,
            data: {
              'search_term': searchTerm,
              'company_id': companyId,
              'limit': limit,
            },
          );

          // For basic search, we'll get logs and filter client-side
          // In production, consider using a proper search service like Algolia
          final snapshot =
              await _firestore
                  .collection('logs')
                  .where('company_id', isEqualTo: companyId)
                  .orderBy('timestamp', descending: true)
                  .limit(limit * 2) // Get more docs to account for filtering
                  .get();

          final allLogs = await _processLogDocuments(snapshot.docs);

          // Filter by search term
          final searchTermLower = searchTerm.toLowerCase();
          final filteredLogs =
              allLogs
                  .where((log) {
                    final message =
                        (log['message'] ?? '').toString().toLowerCase();
                    final userName =
                        (log['user_name'] ?? '').toString().toLowerCase();
                    final userEmail =
                        (log['user_email'] ?? '').toString().toLowerCase();
                    final category =
                        (log['category'] ?? '').toString().toLowerCase();

                    return message.contains(searchTermLower) ||
                        userName.contains(searchTermLower) ||
                        userEmail.contains(searchTermLower) ||
                        category.contains(searchTermLower);
                  })
                  .take(limit)
                  .toList();

          await _logger.info(
            'Log search completed',
            category: LogCategory.system,
            data: {
              'search_term': searchTerm,
              'total_logs_searched': allLogs.length,
              'matching_logs': filteredLogs.length,
              'company_id': companyId,
            },
          );

          return filteredLogs;
        } catch (e) {
          await _logger.error(
            'Log search failed',
            category: LogCategory.system,
            error: e,
            data: {'search_term': searchTerm, 'limit': limit},
          );
          return [];
        }
      },
      data: {
        'operation': 'search_logs',
        'search_term_length': searchTerm.length,
      },
    );
  }

  // Get logs for a specific date range
  Future<List<Map<String, dynamic>>> getLogsByDateRange({
    required DateTime startDate,
    required DateTime endDate,
    LogCategory? filterCategory,
    LogLevel? filterLevel,
    int limit = 100,
  }) async {
    return await _logger.timeOperation(
      'Get Logs by Date Range',
      () async {
        try {
          if (_currentUserId == null) {
            await _logger.error(
              'Cannot get logs by date range - no current user ID',
              category: LogCategory.system,
            );
            return [];
          }

          // Verify user is admin
          final userDoc =
              await _firestore.collection('accounts').doc(_currentUserId).get();
          if (!userDoc.exists || userDoc.data()!['role'] != 'Administrator') {
            await _logger.logSecurity(
              'Unauthorized date range log access attempt',
              level: LogLevel.warning,
              data: {
                'user_id': _currentUserId,
                'start_date': startDate.toIso8601String(),
                'end_date': endDate.toIso8601String(),
              },
            );
            throw 'Only administrators can view logs';
          }

          final companyId = userDoc.data()!['company_id'];

          await _logger.debug(
            'Getting logs by date range',
            category: LogCategory.system,
            data: {
              'start_date': startDate.toIso8601String(),
              'end_date': endDate.toIso8601String(),
              'filter_category': filterCategory?.name,
              'filter_level': filterLevel?.name,
              'company_id': companyId,
            },
          );

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
            query = query.where('category', isEqualTo: filterCategory.name);
          }

          // Add level filter if specified
          if (filterLevel != null) {
            query = query.where('level', isEqualTo: filterLevel.name);
          }

          query = query.limit(limit);

          final snapshot = await query.get();
          final logs = await _processLogDocuments(snapshot.docs);

          await _logger.info(
            'Date range log retrieval completed',
            category: LogCategory.system,
            data: {
              'start_date': startDate.toIso8601String(),
              'end_date': endDate.toIso8601String(),
              'logs_found': logs.length,
              'company_id': companyId,
            },
          );

          return logs;
        } catch (e) {
          await _logger.error(
            'Failed to get logs by date range',
            category: LogCategory.system,
            error: e,
            data: {
              'start_date': startDate.toIso8601String(),
              'end_date': endDate.toIso8601String(),
            },
          );
          return [];
        }
      },
      data: {
        'operation': 'get_logs_by_date_range',
        'date_range_days': endDate.difference(startDate).inDays,
      },
    );
  }

  // Get activity summary (counts by category and level)
  Future<Map<String, dynamic>> getActivitySummary({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return await _logger.timeOperation(
      'Get Activity Summary',
      () async {
        try {
          if (_currentUserId == null) {
            await _logger.error(
              'Cannot get activity summary - no current user ID',
              category: LogCategory.system,
            );
            return {};
          }

          // Verify user is admin
          final userDoc =
              await _firestore.collection('accounts').doc(_currentUserId).get();
          if (!userDoc.exists || userDoc.data()!['role'] != 'Administrator') {
            await _logger.logSecurity(
              'Unauthorized activity summary access attempt',
              level: LogLevel.warning,
              data: {'user_id': _currentUserId},
            );
            throw 'Only administrators can view activity summary';
          }

          final companyId = userDoc.data()!['company_id'];

          await _logger.debug(
            'Generating activity summary',
            category: LogCategory.system,
            data: {
              'company_id': companyId,
              'has_date_range': startDate != null && endDate != null,
            },
          );

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

          await _logger.info(
            'Activity summary generated',
            category: LogCategory.system,
            data: {
              'total_logs': totalLogs,
              'categories_found': categoryCount.length,
              'levels_found': levelCount.length,
              'company_id': companyId,
            },
          );

          return summary;
        } catch (e) {
          await _logger.error(
            'Failed to generate activity summary',
            category: LogCategory.system,
            error: e,
            data: {
              'start_date': startDate?.toIso8601String(),
              'end_date': endDate?.toIso8601String(),
            },
          );
          return {};
        }
      },
      data: {
        'operation': 'get_activity_summary',
        'has_date_filter': startDate != null && endDate != null,
      },
    );
  }

  // Export logs to CSV format (returns data that can be converted to CSV)
  Future<List<Map<String, dynamic>>> getLogsForExport({
    LogCategory? filterCategory,
    LogLevel? filterLevel,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return await _logger.timeOperation(
      'Export Logs',
      () async {
        try {
          if (_currentUserId == null) {
            await _logger.error(
              'Cannot export logs - no current user ID',
              category: LogCategory.system,
            );
            return [];
          }

          // Verify user is admin
          final userDoc =
              await _firestore.collection('accounts').doc(_currentUserId).get();
          if (!userDoc.exists || userDoc.data()!['role'] != 'Administrator') {
            await _logger.logSecurity(
              'Unauthorized log export attempt',
              level: LogLevel.warning,
              data: {
                'user_id': _currentUserId,
                'export_category': filterCategory?.name,
                'export_level': filterLevel?.name,
              },
            );
            throw 'Only administrators can export logs';
          }

          final companyId = userDoc.data()!['company_id'];

          await _logger.info(
            'Starting log export',
            category: LogCategory.system,
            data: {
              'company_id': companyId,
              'filter_category': filterCategory?.name,
              'filter_level': filterLevel?.name,
              'has_date_range': startDate != null && endDate != null,
            },
          );

          // Build query
          Query query = _firestore
              .collection('logs')
              .where('company_id', isEqualTo: companyId)
              .orderBy('timestamp', descending: true);

          // Add category filter
          if (filterCategory != null) {
            query = query.where('category', isEqualTo: filterCategory.name);
          }

          // Add level filter
          if (filterLevel != null) {
            query = query.where('level', isEqualTo: filterLevel.name);
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
          final exportData =
              logs
                  .map(
                    (log) => {
                      'Timestamp': _formatTimestamp(log['timestamp']),
                      'Level': log['level'] ?? 'N/A',
                      'Category': log['category'] ?? 'N/A',
                      'Message': log['message'] ?? 'N/A',
                      'User': log['user_name'] ?? 'N/A',
                      'Email': log['user_email'] ?? 'N/A',
                      'Role': log['user_role'] ?? 'N/A',
                      'Company ID': log['company_id'] ?? 'N/A',
                    },
                  )
                  .toList();

          await _logger.info(
            'Log export completed',
            category: LogCategory.system,
            data: {
              'exported_logs': exportData.length,
              'company_id': companyId,
              'filter_category': filterCategory?.name,
              'filter_level': filterLevel?.name,
            },
          );

          return exportData;
        } catch (e) {
          await _logger.error(
            'Log export failed',
            category: LogCategory.system,
            error: e,
            data: {
              'filter_category': filterCategory?.name,
              'filter_level': filterLevel?.name,
            },
          );
          return [];
        }
      },
      data: {
        'operation': 'export_logs',
        'filter_category': filterCategory?.name,
        'filter_level': filterLevel?.name,
      },
    );
  }

  // Get available log categories (from AppLogger)
  static List<String> getLogCategories() {
    return ['All', ...LogCategory.values.map((e) => e.name)];
  }

  // Get available log levels (from AppLogger)
  static List<String> getLogLevels() {
    return ['All', ...LogLevel.values.map((e) => e.name)];
  }

  // Private helper methods
  Future<List<Map<String, dynamic>>> _processLogDocuments(
    List<QueryDocumentSnapshot> docs,
  ) async {
    List<Map<String, dynamic>> logs = [];
    int processedCount = 0;
    int errorCount = 0;

    await _logger.debug(
      'Processing log documents',
      category: LogCategory.system,
      data: {'total_docs': docs.length},
    );

    for (var doc in docs) {
      try {
        final logData = doc.data() as Map<String, dynamic>;
        logData['document_id'] = doc.id;

        // Map your field names to what the UI expects
        logData['category'] =
            logData['type'] ?? 'unknown'; // Map 'type' to 'category'
        logData['message'] =
            logData['log_desc'] ?? 'No message'; // Map 'log_desc' to 'message'
        logData['timestamp'] =
            logData['created_at']; // Map 'created_at' to 'timestamp'
        logData['level'] = 'info'; // Set a default level since it's missing

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

              await _logger.warning(
                'User not found for log entry',
                category: LogCategory.system,
                data: {
                  'log_id': logData['log_id'],
                  'missing_user_id': logData['user_id'],
                },
              );
            }
          } catch (e) {
            logData['user_name'] = 'Unknown User';
            logData['user_email'] = 'N/A';
            logData['user_role'] = 'N/A';
            errorCount++;

            await _logger.error(
              'Error getting user info for log',
              category: LogCategory.system,
              error: e,
              data: {
                'log_id': logData['log_id'],
                'user_id': logData['user_id'],
              },
            );
          }
        } else {
          logData['user_name'] = 'System';
          logData['user_email'] = 'N/A';
          logData['user_role'] = 'System';
        }

        logs.add(logData);
        processedCount++;
      } catch (e) {
        errorCount++;
        await _logger.error(
          'Error processing log document',
          category: LogCategory.system,
          error: e,
          data: {'document_id': doc.id},
        );
      }
    }

    await _logger.debug(
      'Log document processing completed',
      category: LogCategory.system,
      data: {
        'total_docs': docs.length,
        'processed_successfully': processedCount,
        'errors': errorCount,
      },
    );

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
