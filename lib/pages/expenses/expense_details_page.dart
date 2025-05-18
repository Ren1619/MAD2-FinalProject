import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/firebase_auth_service.dart';
import '../../services/firebase_logs_service.dart';
import '../../widgets/common_widgets.dart';
import '../../theme.dart';

class LogsPage extends StatefulWidget {
  const LogsPage({super.key});

  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  List<Map<String, dynamic>> _logs = [];
  List<Map<String, dynamic>> _filteredLogs = [];
  Map<String, dynamic>? _userData;
  Map<String, int> _activitySummary = {};
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String _searchQuery = '';
  String _typeFilter = 'All';
  DateTimeRange? _dateRange;

  final List<String> _logTypes = [
    'All',
    'Authentication',
    'Account Management',
    'Budget Management',
    'Expense Management',
    'System',
  ];

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
      await _loadLogs();
      await _loadActivitySummary();
    }

    setState(() => _isLoading = false);
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);

    try {
      final logsService = Provider.of<FirebaseLogsService>(
        context,
        listen: false,
      );

      List<Map<String, dynamic>> logs;

      if (_dateRange != null) {
        logs = await logsService.getLogsByDateRange(
          startDate: _dateRange!.start,
          endDate: _dateRange!.end,
          filterType: _typeFilter == 'All' ? null : _typeFilter,
          limit: 100,
        );
      } else {
        logs = await logsService.getLogsForAdmin(
          filterType: _typeFilter == 'All' ? null : _typeFilter,
          limit: 100,
        );
      }

      setState(() {
        _logs = logs;
        _filteredLogs = logs;
      });

      _applyFilters();
    } catch (e) {
      _showErrorSnackBar('Error loading logs: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadActivitySummary() async {
    try {
      final logsService = Provider.of<FirebaseLogsService>(
        context,
        listen: false,
      );
      final summary = await logsService.getActivitySummary(
        startDate: _dateRange?.start,
        endDate: _dateRange?.end,
      );

      setState(() => _activitySummary = summary);
    } catch (e) {
      print('Error loading activity summary: $e');
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredLogs =
          _logs.where((log) {
            // Search filter
            if (_searchQuery.isNotEmpty) {
              final searchLower = _searchQuery.toLowerCase();
              final description = (log['log_desc'] ?? '').toLowerCase();
              final userName = (log['user_name'] ?? '').toLowerCase();
              final userEmail = (log['user_email'] ?? '').toLowerCase();
              final type = (log['type'] ?? '').toLowerCase();

              if (!description.contains(searchLower) &&
                  !userName.contains(searchLower) &&
                  !userEmail.contains(searchLower) &&
                  !type.contains(searchLower)) {
                return false;
              }
            }

            return true;
          }).toList();
    });
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
      helpText: 'Select Date Range',
      fieldStartLabelText: 'Start Date',
      fieldEndLabelText: 'End Date',
    );

    if (picked != null && picked != _dateRange) {
      setState(() => _dateRange = picked);
      await _loadLogs();
      await _loadActivitySummary();
    }
  }

  void _clearDateRange() {
    setState(() => _dateRange = null);
    _loadLogs();
    _loadActivitySummary();
  }

  Future<void> _exportLogs() async {
    try {
      final logsService = Provider.of<FirebaseLogsService>(
        context,
        listen: false,
      );
      final exportData = await logsService.getLogsForExport(
        filterType: _typeFilter == 'All' ? null : _typeFilter,
        startDate: _dateRange?.start,
        endDate: _dateRange?.end,
      );

      // In a real implementation, you would handle the CSV export here
      // For now, we'll just show a success message
      _showSuccessSnackBar(
        'Export data prepared (${exportData.length} records)',
      );
    } catch (e) {
      _showErrorSnackBar('Error exporting logs: $e');
    }
  }

  void _showLogDetails(Map<String, dynamic> log) {
    showDialog(
      context: context,
      builder: (context) => _LogDetailsDialog(log: log),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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

      return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Invalid Date';
    }
  }

  String _formatDateRange() {
    if (_dateRange == null) return 'All Time';

    final start = _dateRange!.start;
    final end = _dateRange!.end;

    return '${start.day}/${start.month}/${start.year} - ${end.day}/${end.month}/${end.year}';
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'Authentication':
        return Colors.blue;
      case 'Account Management':
        return Colors.green;
      case 'Budget Management':
        return Colors.purple;
      case 'Expense Management':
        return Colors.orange;
      case 'System':
        return Colors.grey;
      default:
        return AppTheme.primaryColor;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'Authentication':
        return Icons.login;
      case 'Account Management':
        return Icons.people;
      case 'Budget Management':
        return Icons.account_balance_wallet;
      case 'Expense Management':
        return Icons.receipt;
      case 'System':
        return Icons.settings;
      default:
        return Icons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check if user is admin
    if (_userData != null && _userData!['role'] != 'Administrator') {
      return Scaffold(
        appBar: CustomAppBar(title: 'Activity Logs'),
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
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _exportLogs,
            tooltip: 'Export Logs',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadLogs();
              _loadActivitySummary();
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Header Section with Stats
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                // Activity Summary
                Row(
                  children: [
                    Icon(Icons.analytics, color: AppTheme.primaryColor),
                    const SizedBox(width: 8),
                    Text(
                      'Activity Overview',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Period: ${_formatDateRange()}',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Stats Cards
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Authentication',
                        _activitySummary['Authentication'] ?? 0,
                        Icons.login,
                        Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildStatCard(
                        'Account Mgmt',
                        _activitySummary['Account Management'] ?? 0,
                        Icons.people,
                        Colors.green,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildStatCard(
                        'Budget Mgmt',
                        _activitySummary['Budget Management'] ?? 0,
                        Icons.account_balance_wallet,
                        Colors.purple,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildStatCard(
                        'Expense Mgmt',
                        _activitySummary['Expense Management'] ?? 0,
                        Icons.receipt,
                        Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildStatCard(
                        'System',
                        _activitySummary['System'] ?? 0,
                        Icons.settings,
                        Colors.grey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Filters Section
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                Row(
                  children: [
                    // Search Field
                    Expanded(
                      flex: 2,
                      child: CustomSearchField(
                        hintText:
                            'Search logs by description, user, or type...',
                        onChanged: (value) {
                          setState(() => _searchQuery = value);
                          _applyFilters();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Type Filter
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Type',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        value: _typeFilter,
                        items:
                            _logTypes.map((type) {
                              return DropdownMenuItem(
                                value: type,
                                child: Text(type),
                              );
                            }).toList(),
                        onChanged: (value) {
                          setState(() => _typeFilter = value!);
                          _loadLogs();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Date Range Filter
                    OutlinedButton.icon(
                      onPressed: _selectDateRange,
                      icon: const Icon(Icons.date_range),
                      label: Text(
                        _dateRange == null ? 'Date Range' : 'Custom Range',
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),

                    if (_dateRange != null) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _clearDateRange,
                        icon: const Icon(Icons.clear),
                        tooltip: 'Clear Date Range',
                      ),
                    ],
                  ],
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
                    'Latest: ${_formatTimestamp(_filteredLogs.isNotEmpty ? _filteredLogs.first['created_at'] : null)}',
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
                          _searchQuery.isNotEmpty ||
                                  _typeFilter != 'All' ||
                                  _dateRange != null
                              ? 'No logs match your search criteria.\nTry adjusting your filters.'
                              : 'No activity logs found.\nLogs will appear here as users perform actions.',
                      icon: Icons.history,
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

  Widget _buildStatCard(String title, int count, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(fontSize: 10, color: Colors.black87),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildLogCard(Map<String, dynamic> log) {
    final type = log['type'] ?? 'Unknown';
    final color = _getTypeColor(type);
    final icon = _getTypeIcon(type);
    final isSystemLog = log['user_name'] == 'System';

    return HoverCard(
      onTap: () => _showLogDetails(log),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Type Icon
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 16),
                ),
                const SizedBox(width: 12),

                // Log Description
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        log['log_desc'] ?? 'No description',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              type,
                              style: TextStyle(
                                fontSize: 10,
                                color: color,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.access_time,
                            size: 12,
                            color: AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatTimestamp(log['created_at']),
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // User Info
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isSystemLog)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.computer,
                                  size: 12,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'System',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else ...[
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: AppTheme.primaryLightColor,
                            child: Text(
                              (log['user_name'] ?? '')
                                  .split(' ')
                                  .map((e) => e.isNotEmpty ? e[0] : '')
                                  .join('')
                                  .toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                log['user_name'] ?? 'Unknown User',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (log['user_role'] != null)
                                Text(
                                  log['user_role'],
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Log Details Dialog
class _LogDetailsDialog extends StatelessWidget {
  final Map<String, dynamic> log;

  const _LogDetailsDialog({required this.log});

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';

    try {
      DateTime dateTime;
      if (timestamp is String) {
        dateTime = DateTime.parse(timestamp);
      } else {
        dateTime = timestamp.toDate();
      }

      return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Invalid Date';
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'Authentication':
        return Colors.blue;
      case 'Account Management':
        return Colors.green;
      case 'Budget Management':
        return Colors.purple;
      case 'Expense Management':
        return Colors.orange;
      case 'System':
        return Colors.grey;
      default:
        return AppTheme.primaryColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final type = log['type'] ?? 'Unknown';
    final color = _getTypeColor(type);

    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.info, color: color),
          ),
          const SizedBox(width: 12),
          Text(
            'Activity Log Details',
            style: TextStyle(color: AppTheme.primaryColor),
          ),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Description', log['log_desc'] ?? 'No description'),
            _buildDetailRow('Type', type),
            _buildDetailRow('Log ID', log['log_id'] ?? 'Unknown'),
            _buildDetailRow('Timestamp', _formatTimestamp(log['created_at'])),
            _buildDetailRow('User', log['user_name'] ?? 'System'),
            if (log['user_email'] != null)
              _buildDetailRow('Email', log['user_email']),
            if (log['user_role'] != null)
              _buildDetailRow('Role', log['user_role']),
            if (log['company_id'] != null)
              _buildDetailRow('Company ID', log['company_id']),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: TextStyle(color: AppTheme.textPrimary)),
          ),
        ],
      ),
    );
  }
}
