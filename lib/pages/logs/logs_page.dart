import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/firebase_auth_service.dart';
import '../../services/firebase_logs_service.dart';
import '../../services/app_logger.dart';
import '../../widgets/common_widgets.dart';
import '../../theme.dart';

class LogsPage extends StatefulWidget {
  final VoidCallback? onOpenDrawer;
  final Map<String, dynamic>? userData;
  const LogsPage({super.key, this.onOpenDrawer, this.userData});

  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  List<Map<String, dynamic>> _logs = [];
  List<Map<String, dynamic>> _filteredLogs = [];
  Map<String, dynamic>? _userData;
  Map<String, dynamic> _debugInfo = {};
  bool _isLoading = true;
  bool _showDebugInfo = false;
  String _searchQuery = '';
  String _categoryFilter = 'All';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final authService = Provider.of<FirebaseAuthService>(
      context,
      listen: false,
    );
    final userData = await authService.currentUser;

    setState(() => _userData = userData);

    if (userData != null && userData['role'] == 'Administrator') {
      await _testDatabaseStructure();
      await _loadLogs();
    }

    setState(() => _isLoading = false);
  }

  // Quick diagnostic function
  Future<void> _runQuickDiagnostic() async {
    print('🔍 DIAGNOSTIC: Starting quick logs diagnostic...');

    try {
      // Step 1: Check current user
      final authService = Provider.of<FirebaseAuthService>(
        context,
        listen: false,
      );
      final userData = await authService.currentUser;

      print('🔍 DIAGNOSTIC: Current user: ${userData?['email']}');
      print('🔍 DIAGNOSTIC: User role: ${userData?['role']}');
      print('🔍 DIAGNOSTIC: Company ID: ${userData?['company_id']}');

      if (userData == null) {
        print('❌ DIAGNOSTIC: No user logged in!');
        _showErrorSnackBar('No user logged in!');
        return;
      }

      if (userData['role'] != 'Administrator') {
        print('❌ DIAGNOSTIC: User is not administrator!');
        _showErrorSnackBar('User is not administrator!');
        return;
      }

      final companyId = userData['company_id'];
      if (companyId == null) {
        print('❌ DIAGNOSTIC: User has no company_id!');
        _showErrorSnackBar('User has no company_id!');
        return;
      }

      // Step 2: Check total logs in database
      final allLogsSnapshot =
          await FirebaseFirestore.instance.collection('logs').limit(10).get();

      print(
        '🔍 DIAGNOSTIC: Total logs in database: ${allLogsSnapshot.docs.length}',
      );

      if (allLogsSnapshot.docs.isEmpty) {
        print('❌ DIAGNOSTIC: No logs found in database at all!');
        _showErrorSnackBar('No logs found in database at all!');
        return;
      }

      // Step 3: Examine first log structure
      final firstLog = allLogsSnapshot.docs.first.data();
      print('🔍 DIAGNOSTIC: First log fields: ${firstLog.keys.toList()}');
      print('🔍 DIAGNOSTIC: First log company_id: ${firstLog['company_id']}');

      // Step 4: Check logs for your company
      final companyLogsSnapshot =
          await FirebaseFirestore.instance
              .collection('logs')
              .where('company_id', isEqualTo: companyId)
              .limit(10)
              .get();

      print(
        '🔍 DIAGNOSTIC: Logs for your company: ${companyLogsSnapshot.docs.length}',
      );

      if (companyLogsSnapshot.docs.isEmpty) {
        print('❌ DIAGNOSTIC: No logs found for your company!');
        _showErrorSnackBar(
          'No logs found for your company! Company ID: $companyId',
        );

        // Check if any logs have a different company_id
        final allCompanyIds =
            allLogsSnapshot.docs
                .map((doc) => doc.data()['company_id'])
                .where((id) => id != null)
                .toSet()
                .toList();

        print('🔍 DIAGNOSTIC: Company IDs found in logs: $allCompanyIds');
        return;
      }

      _showSuccessSnackBar(
        'Diagnostic completed! Found ${companyLogsSnapshot.docs.length} logs for your company.',
      );
    } catch (e, stackTrace) {
      print('❌ DIAGNOSTIC: Error during diagnostic: $e');
      print('❌ DIAGNOSTIC: Stack trace: $stackTrace');
      _showErrorSnackBar('Diagnostic failed: $e');
    }
  }

  Future<void> _testDatabaseStructure() async {
    try {
      final logsService = Provider.of<FirebaseLogsService>(
        context,
        listen: false,
      );
      final debugInfo = await logsService.testDatabaseStructure();
      setState(() => _debugInfo = debugInfo);

      print('🔍 DEBUG INFO: $debugInfo');
    } catch (e) {
      print('❌ DEBUG: Failed to test database structure: $e');
    }
  }

  Future<void> _createTestLog() async {
    try {
      final logsService = Provider.of<FirebaseLogsService>(
        context,
        listen: false,
      );
      final success = await logsService.createTestLog();

      if (success) {
        _showSuccessSnackBar('Test log created successfully!');
        // Reload logs to show the new test log
        await Future.delayed(
          Duration(seconds: 2),
        ); // Wait for Firestore to sync
        await _loadLogs();
      } else {
        _showErrorSnackBar('Failed to create test log');
      }
    } catch (e) {
      _showErrorSnackBar('Error creating test log: $e');
    }
  }

  Future<void> _createProperTestLogs() async {
    try {
      final authService = Provider.of<FirebaseAuthService>(
        context,
        listen: false,
      );
      final userData = await authService.currentUser;

      if (userData == null || userData['role'] != 'Administrator') {
        _showErrorSnackBar('Cannot create test logs - not administrator');
        return;
      }

      final companyId = userData['company_id'];
      if (companyId == null) {
        _showErrorSnackBar('Cannot create test logs - no company ID');
        return;
      }

      print('🔍 Creating properly formatted test logs...');

      final testLogs = [
        {
          'message': 'User logged in successfully',
          'category': 'authentication',
          'level': 'info',
          'type': 'Authentication',
        },
        {
          'message': 'Budget created: Monthly Office Supplies',
          'category': 'budgetManagement',
          'level': 'info',
          'type': 'Budget Management',
        },
        {
          'message': 'Expense submitted for approval',
          'category': 'expenseManagement',
          'level': 'info',
          'type': 'Expense Management',
        },
        {
          'message': 'New user account created',
          'category': 'accountManagement',
          'level': 'info',
          'type': 'Account Management',
        },
        {
          'message': 'System maintenance completed',
          'category': 'system',
          'level': 'info',
          'type': 'System',
        },
      ];

      for (int i = 0; i < testLogs.length; i++) {
        final testLog = testLogs[i];

        await FirebaseFirestore.instance.collection('logs').add({
          'log_id': 'test_${DateTime.now().millisecondsSinceEpoch}_$i',
          'message': testLog['message'],
          'log_desc': testLog['message'], // For compatibility
          'level': testLog['level'],
          'category': testLog['category'],
          'type': testLog['type'], // For compatibility
          'timestamp': FieldValue.serverTimestamp(),
          'created_at': FieldValue.serverTimestamp(), // For compatibility
          'user_id': userData['account_id'],
          'company_id': companyId,
          'user_name': '${userData['f_name']} ${userData['l_name']}',
          'user_email': userData['email'],
          'user_role': userData['role'],
          'client_timestamp': DateTime.now().toIso8601String(),
          'app_version': '1.0.0',
          'platform': 'web',
        });

        print('✅ Created test log ${i + 1}: ${testLog['message']}');
      }

      _showSuccessSnackBar(
        'All ${testLogs.length} test logs created successfully!',
      );

      // Reload logs after creation
      await Future.delayed(Duration(seconds: 3));
      await _loadLogs();
    } catch (e) {
      print('❌ Error creating test logs: $e');
      _showErrorSnackBar('Error creating test logs: $e');
    }
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);

    try {
      final logsService = Provider.of<FirebaseLogsService>(
        context,
        listen: false,
      );

      print('🔍 DEBUG: Starting to load logs...');
      print('🔍 DEBUG: Current user data: $_userData');
      print('🔍 DEBUG: User role: ${_userData?['role']}');
      print('🔍 DEBUG: User company_id: ${_userData?['company_id']}');

      // Use only the core getLogsForAdmin method
      final logs = await logsService.getLogsForAdmin(
        filterCategory: _categoryFilter == 'All' ? null : _categoryFilter,
        limit: 100,
      );

      print('🔍 DEBUG: Logs loaded successfully');
      print('🔍 DEBUG: Number of logs returned: ${logs.length}');

      if (logs.isNotEmpty) {
        print('🔍 DEBUG: First log sample: ${logs.first}');
      } else {
        print('⚠️ DEBUG: No logs returned - checking debug info');
        print('🔍 DEBUG: Debug info: $_debugInfo');
      }

      setState(() {
        _logs = logs;
        _filteredLogs = logs;
      });

      _applyFilters();
    } catch (e) {
      print('❌ DEBUG: Error loading logs: $e');
      _showErrorSnackBar('Error loading logs: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredLogs =
          _logs.where((log) {
            // Search filter
            if (_searchQuery.isNotEmpty) {
              final searchLower = _searchQuery.toLowerCase();
              final message = (log['message'] ?? '').toLowerCase();
              final userName = (log['user_name'] ?? '').toLowerCase();
              final userEmail = (log['user_email'] ?? '').toLowerCase();
              final category = (log['category'] ?? '').toLowerCase();

              if (!message.contains(searchLower) &&
                  !userName.contains(searchLower) &&
                  !userEmail.contains(searchLower) &&
                  !category.contains(searchLower)) {
                return false;
              }
            }

            return true;
          }).toList();
    });
  }

  void _showLogDetails(Map<String, dynamic> log) {
    showDialog(
      context: context,
      builder: (context) => _LogDetailsDialog(log: log),
    );
  }

  void _showDebugDialog() {
    showDialog(
      context: context,
      builder:
          (context) => _DebugInfoDialog(
            debugInfo: _debugInfo,
            onCreateTestLog: _createTestLog,
            onCreateProperTestLogs: _createProperTestLogs,
            onRunDiagnostic: _runQuickDiagnostic,
            onRefresh: () {
              Navigator.pop(context);
              _testDatabaseStructure();
              _loadLogs();
            },
          ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: Duration(seconds: 5),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: Duration(seconds: 5),
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';

    try {
      DateTime dateTime;
      if (timestamp is String) {
        dateTime = DateTime.parse(timestamp);
      } else {
        dateTime = timestamp.toDate();
      }

      return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Invalid Date';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check if user is admin
    if (_userData != null && _userData!['role'] != 'Administrator') {
      return Scaffold(
        appBar: CustomAppBar(
          title: 'Activity Logs',
          onMenuPressed: widget.onOpenDrawer,
          userData: widget.userData,
        ),
        body: const EmptyStateWidget(
          message:
              'Access Denied\n\nOnly administrators can view activity logs.',
          icon: Icons.lock,
        ),
      );
    }

    if (_isLoading) {
      return const Scaffold(
        body: LoadingIndicator(message: 'Loading activity logs...'),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: CustomAppBar(
        title: 'Activity Logs',
        onMenuPressed: widget.onOpenDrawer,
        userData: widget.userData,
        actions: [
          // Debug button
          IconButton(
            icon: Icon(Icons.bug_report, color: Colors.orange),
            onPressed: _showDebugDialog,
            tooltip: 'Debug Tools',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _testDatabaseStructure();
              _loadLogs();
            },
            tooltip: 'Refresh',
          ),
        ],
      ),

      // Floating Action Buttons
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Diagnostic Button
          FloatingActionButton(
            onPressed: _runQuickDiagnostic,
            backgroundColor: Colors.purple,
            foregroundColor: Colors.white,
            heroTag: "diagnostic",
            child: const Icon(Icons.search),
            tooltip: 'Run Diagnostic',
          ),
          const SizedBox(height: 10),
          // Test Logs Button
          FloatingActionButton(
            onPressed: _createProperTestLogs,
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            heroTag: "testLogs",
            child: const Icon(Icons.add_circle),
            tooltip: 'Create Multiple Test Logs',
          ),
          const SizedBox(height: 10),
          // Single Test Log Button
          FloatingActionButton(
            onPressed: _createTestLog,
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            heroTag: "singleTestLog",
            child: const Icon(Icons.add),
            tooltip: 'Create Single Test Log',
          ),
        ],
      ),

      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: Column(
        children: [
          // Debug Info Banner (if no logs found)
          if (_logs.isEmpty && !_isLoading)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.orange[50],
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'No logs found',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange[700],
                          ),
                        ),
                        Text(
                          'Total logs in database: ${_debugInfo['total_logs'] ?? 'Unknown'}',
                          style: TextStyle(color: Colors.orange[600]),
                        ),
                        Text(
                          'Company logs: ${_debugInfo['company_logs_count'] ?? 'Unknown'}',
                          style: TextStyle(color: Colors.orange[600]),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _showDebugDialog,
                    child: const Text('Debug'),
                  ),
                ],
              ),
            ),

          // Simple filters
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                // Search Field
                Expanded(
                  flex: 2,
                  child: CustomSearchField(
                    hintText: 'Search logs...',
                    onChanged: (value) {
                      setState(() => _searchQuery = value);
                      _applyFilters();
                    },
                  ),
                ),
                const SizedBox(width: 12),

                // Category Filter
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    value: _categoryFilter,
                    items:
                        [
                          'All',
                          'Authentication',
                          'Account Management',
                          'Budget Management',
                          'Expense Management',
                          'System',
                        ].map((category) {
                          return DropdownMenuItem(
                            value: category,
                            child: Text(category),
                          );
                        }).toList(),
                    onChanged: (value) {
                      setState(() => _categoryFilter = value!);
                      _loadLogs();
                    },
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Results Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.grey[50],
            child: Row(
              children: [
                Text(
                  'Found ${_filteredLogs.length} log(s)',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const Spacer(),
                if (_filteredLogs.isNotEmpty)
                  Text(
                    'Latest: ${_formatTimestamp(_filteredLogs.first['timestamp'] ?? _filteredLogs.first['created_at'])}',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
              ],
            ),
          ),

          // Logs List
          Expanded(
            child:
                _filteredLogs.isEmpty
                    ? EmptyStateWidget(
                      message:
                          _searchQuery.isNotEmpty || _categoryFilter != 'All'
                              ? 'No logs match your search criteria.\nTry adjusting your filters or create test logs.'
                              : 'No activity logs found.\n\nUse the diagnostic tools to troubleshoot:\n• Purple button: Run diagnostic\n• Orange button: Create 5 test logs\n• Blue button: Create 1 test log',
                      icon: Icons.history,
                      actionLabel: 'Run Diagnostic',
                      onActionPressed: _runQuickDiagnostic,
                    )
                    : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _filteredLogs.length,
                      itemBuilder: (context, index) {
                        return _buildLogCard(_filteredLogs[index]);
                      },
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogCard(Map<String, dynamic> log) {
    final level = log['level'] ?? 'info';
    final category = log['category'] ?? log['type'] ?? 'unknown';

    return HoverCard(
      onTap: () => _showLogDetails(log),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Level indicator
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getLevelColor(level).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    level.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: _getLevelColor(level),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Category
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    category,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[700],
                    ),
                  ),
                ),
                const Spacer(),
                // Timestamp
                Text(
                  _formatTimestamp(log['timestamp'] ?? log['created_at']),
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Message
            Text(
              log['message'] ?? log['log_desc'] ?? 'No message',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (log['user_name'] != null) ...[
              const SizedBox(height: 4),
              Text(
                'User: ${log['user_name']} (${log['user_role'] ?? 'Unknown Role'})',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getLevelColor(String level) {
    switch (level.toLowerCase()) {
      case 'debug':
        return Colors.grey;
      case 'info':
        return Colors.blue;
      case 'warning':
        return Colors.orange;
      case 'error':
        return Colors.red;
      case 'critical':
        return Colors.red[900]!;
      default:
        return AppTheme.primaryColor;
    }
  }
}

// Debug Info Dialog
class _DebugInfoDialog extends StatelessWidget {
  final Map<String, dynamic> debugInfo;
  final VoidCallback onCreateTestLog;
  final VoidCallback onCreateProperTestLogs;
  final VoidCallback onRunDiagnostic;
  final VoidCallback onRefresh;

  const _DebugInfoDialog({
    required this.debugInfo,
    required this.onCreateTestLog,
    required this.onCreateProperTestLogs,
    required this.onRunDiagnostic,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.bug_report, color: Colors.orange),
          const SizedBox(width: 8),
          const Text('Debug Tools'),
        ],
      ),
      content: SizedBox(
        width: 500,
        height: 400,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDebugSection('Quick Actions', []),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        onRunDiagnostic();
                      },
                      icon: Icon(Icons.search),
                      label: Text('Run Diagnostic'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        onCreateProperTestLogs();
                      },
                      icon: Icon(Icons.add_circle),
                      label: Text('Create 5 Test Logs'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              _buildDebugSection('Database Status', [
                'Total logs in database: ${debugInfo['total_logs'] ?? 'Unknown'}',
                'Current user ID: ${debugInfo['current_user_id'] ?? 'Unknown'}',
                'Company logs count: ${debugInfo['company_logs_count'] ?? 'Unknown'}',
              ]),
              const SizedBox(height: 16),

              _buildDebugSection('User Information', [
                'User role: ${debugInfo['user_data']?['role'] ?? 'Unknown'}',
                'Company ID: ${debugInfo['user_data']?['company_id'] ?? 'Unknown'}',
                'User email: ${debugInfo['user_data']?['email'] ?? 'Unknown'}',
              ]),
              const SizedBox(height: 16),

              if (debugInfo['sample_log_data'] != null) ...[
                _buildDebugSection('Sample Log Data', [
                  'Message: ${debugInfo['sample_log_data']['message'] ?? debugInfo['sample_log_data']['log_desc'] ?? 'No message'}',
                  'Type: ${debugInfo['sample_log_data']['type'] ?? 'No type'}',
                  'Company ID: ${debugInfo['sample_log_data']['company_id'] ?? 'No company ID'}',
                  'Level: ${debugInfo['sample_log_data']['level'] ?? 'No level'}',
                ]),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: onRefresh, child: const Text('Refresh')),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }

  Widget _buildDebugSection(String title, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.orange,
          ),
        ),
        const SizedBox(height: 8),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 4),
            child: Text('• $item', style: const TextStyle(fontSize: 14)),
          ),
        ),
      ],
    );
  }
}

// Simple Log Details Dialog
class _LogDetailsDialog extends StatelessWidget {
  final Map<String, dynamic> log;

  const _LogDetailsDialog({required this.log});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Log Details'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow(
                'Message',
                log['message'] ?? log['log_desc'] ?? 'No message',
              ),
              _buildDetailRow('Level', (log['level'] ?? 'info').toUpperCase()),
              _buildDetailRow(
                'Category',
                log['category'] ?? log['type'] ?? 'Unknown',
              ),
              _buildDetailRow('User', log['user_name'] ?? 'System'),
              _buildDetailRow('Role', log['user_role'] ?? 'N/A'),
              _buildDetailRow('Email', log['user_email'] ?? 'N/A'),
              _buildDetailRow('Company ID', log['company_id'] ?? 'N/A'),
              _buildDetailRow(
                'Log ID',
                log['log_id'] ?? log['document_id'] ?? 'Unknown',
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label + ':',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
