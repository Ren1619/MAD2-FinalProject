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
  Map<String, dynamic> _activitySummary = {};
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String _searchQuery = '';
  String _categoryFilter = 'All';
  String _levelFilter = 'All';
  DateTimeRange? _dateRange;

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

      // Debug: Check user data first
      print('DEBUG: Current user data: $_userData');
      print('DEBUG: User role: ${_userData?['role']}');
      print('DEBUG: User company_id: ${_userData?['company_id']}');

      // Debug: Try a simple query first to see if there are any logs at all
      final allLogsSnapshot =
          await FirebaseFirestore.instance.collection('logs').get();
      print('DEBUG: Total logs in database: ${allLogsSnapshot.docs.length}');

      if (allLogsSnapshot.docs.isNotEmpty) {
        final firstLog = allLogsSnapshot.docs.first.data();
        print('DEBUG: First log structure: $firstLog');
        print('DEBUG: First log company_id: ${firstLog['company_id']}');
      }

      List<Map<String, dynamic>> logs;

      if (_dateRange != null) {
        logs = await logsService.getLogsByDateRange(
          startDate: _dateRange!.start,
          endDate: _dateRange!.end,
          filterCategory:
              _categoryFilter == 'All'
                  ? null
                  : _getCategoryFromString(_categoryFilter),
          filterLevel:
              _levelFilter == 'All' ? null : _getLevelFromString(_levelFilter),
          limit: 100,
        );
      } else {
        logs = await logsService.getLogsForAdmin(
          filterCategory: _categoryFilter == 'All' ? null : _categoryFilter,
          filterLevel: _levelFilter == 'All' ? null : _levelFilter,
          limit: 100,
        );
      }

      print('DEBUG: Logs returned: ${logs.length}');
      if (logs.isNotEmpty) {
        print('DEBUG: First returned log: ${logs.first}');
      }

      setState(() {
        _logs = logs;
        _filteredLogs = logs;
      });

      _applyFilters();
    } catch (e) {
      print('DEBUG: Error loading logs: $e');
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

  LogCategory? _getCategoryFromString(String categoryName) {
    try {
      return LogCategory.values.firstWhere((e) => e.name == categoryName);
    } catch (e) {
      return null;
    }
  }

  LogLevel? _getLevelFromString(String levelName) {
    try {
      return LogLevel.values.firstWhere((e) => e.name == levelName);
    } catch (e) {
      return null;
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
              final level = (log['level'] ?? '').toLowerCase();

              if (!message.contains(searchLower) &&
                  !userName.contains(searchLower) &&
                  !userEmail.contains(searchLower) &&
                  !category.contains(searchLower) &&
                  !level.contains(searchLower)) {
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
        filterCategory:
            _categoryFilter == 'All'
                ? null
                : _getCategoryFromString(_categoryFilter),
        filterLevel:
            _levelFilter == 'All' ? null : _getLevelFromString(_levelFilter),
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

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'authentication':
        return Colors.blue;
      case 'accountManagement':
        return Colors.green;
      case 'budgetManagement':
        return Colors.purple;
      case 'expenseManagement':
        return Colors.orange;
      case 'system':
      case 'performance':
        return Colors.grey;
      case 'security':
        return Colors.red;
      case 'userAction':
        return Colors.indigo;
      case 'error':
        return Colors.redAccent;
      default:
        return AppTheme.primaryColor;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'authentication':
        return Icons.login;
      case 'accountManagement':
        return Icons.people;
      case 'budgetManagement':
        return Icons.account_balance_wallet;
      case 'expenseManagement':
        return Icons.receipt;
      case 'system':
      case 'performance':
        return Icons.settings;
      case 'security':
        return Icons.security;
      case 'userAction':
        return Icons.touch_app;
      case 'error':
        return Icons.error;
      default:
        return Icons.info;
    }
  }

  Color _getLevelColor(String level) {
    switch (level) {
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

  IconData _getLevelIcon(String level) {
    switch (level) {
      case 'debug':
        return Icons.bug_report;
      case 'info':
        return Icons.info;
      case 'warning':
        return Icons.warning;
      case 'error':
        return Icons.error;
      case 'critical':
        return Icons.dangerous;
      default:
        return Icons.circle;
    }
  }

  String _formatCategoryName(String category) {
    switch (category) {
      case 'authentication':
        return 'Authentication';
      case 'accountManagement':
        return 'Account Management';
      case 'budgetManagement':
        return 'Budget Management';
      case 'expenseManagement':
        return 'Expense Management';
      case 'system':
        return 'System';
      case 'userAction':
        return 'User Action';
      case 'error':
        return 'Error';
      case 'performance':
        return 'Performance';
      case 'security':
        return 'Security';
      default:
        return category;
    }
  }

  String _formatLevelName(String level) {
    return level[0].toUpperCase() + level.substring(1);
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
      // Clean AppBar with only refresh button
      appBar: CustomAppBar(
        title: 'Activity Logs',
        onMenuPressed: widget.onOpenDrawer,
        userData: widget.userData,
        actions: [
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

      // Floating Action Button for Export
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _exportLogs,
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.file_download),
        label: const Text('Export'),
        tooltip: 'Export Logs',
      ),

      // Position FAB in bottom right (default position)
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
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
                if (_activitySummary['by_category'] != null) ...[
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Authentication',
                          (_activitySummary['by_category']
                                  as Map<String, dynamic>)['authentication'] ??
                              0,
                          Icons.login,
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatCard(
                          'Account Mgmt',
                          (_activitySummary['by_category']
                                  as Map<
                                    String,
                                    dynamic
                                  >)['accountManagement'] ??
                              0,
                          Icons.people,
                          Colors.green,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatCard(
                          'Budget Mgmt',
                          (_activitySummary['by_category']
                                  as Map<
                                    String,
                                    dynamic
                                  >)['budgetManagement'] ??
                              0,
                          Icons.account_balance_wallet,
                          Colors.purple,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatCard(
                          'Expense Mgmt',
                          (_activitySummary['by_category']
                                  as Map<
                                    String,
                                    dynamic
                                  >)['expenseManagement'] ??
                              0,
                          Icons.receipt,
                          Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatCard(
                          'System',
                          (_activitySummary['by_category']
                                  as Map<String, dynamic>)['system'] ??
                              0,
                          Icons.settings,
                          Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Level Stats
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Info',
                          (_activitySummary['by_level']
                                  as Map<String, dynamic>)['info'] ??
                              0,
                          Icons.info,
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatCard(
                          'Warning',
                          (_activitySummary['by_level']
                                  as Map<String, dynamic>)['warning'] ??
                              0,
                          Icons.warning,
                          Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatCard(
                          'Error',
                          (_activitySummary['by_level']
                                  as Map<String, dynamic>)['error'] ??
                              0,
                          Icons.error,
                          Colors.red,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatCard(
                          'Critical',
                          (_activitySummary['by_level']
                                  as Map<String, dynamic>)['critical'] ??
                              0,
                          Icons.dangerous,
                          Colors.red[900]!,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatCard(
                          'Total',
                          _activitySummary['total_logs'] ?? 0,
                          Icons.list,
                          AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ],
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
                            'Search logs by message, user, category, or level...',
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
                            FirebaseLogsService.getLogCategories().map((
                              category,
                            ) {
                              return DropdownMenuItem(
                                value: category,
                                child: Text(
                                  category == 'All'
                                      ? category
                                      : _formatCategoryName(category),
                                ),
                              );
                            }).toList(),
                        onChanged: (value) {
                          setState(() => _categoryFilter = value!);
                          _loadLogs();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Level Filter
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Level',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        value: _levelFilter,
                        items:
                            FirebaseLogsService.getLogLevels().map((level) {
                              return DropdownMenuItem(
                                value: level,
                                child: Text(
                                  level == 'All'
                                      ? level
                                      : _formatLevelName(level),
                                ),
                              );
                            }).toList(),
                        onChanged: (value) {
                          setState(() => _levelFilter = value!);
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
                    'Latest: ${_formatTimestamp(_filteredLogs.isNotEmpty ? _filteredLogs.first['timestamp'] : null)}',
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
                                  _categoryFilter != 'All' ||
                                  _levelFilter != 'All' ||
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
    final category = log['category'] ?? 'unknown';
    final level = log['level'] ?? 'info';
    final categoryColor = _getCategoryColor(category);
    final levelColor = _getLevelColor(level);
    final categoryIcon = _getCategoryIcon(category);
    final levelIcon = _getLevelIcon(level);
    final isSystemLog = log['user_name'] == 'System';

    return HoverCard(
      onTap: () => _showLogDetails(log),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: levelColor.withOpacity(0.2)),
          boxShadow:
              level == 'error' || level == 'critical'
                  ? [
                    BoxShadow(
                      color: levelColor.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                  : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Category Icon
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: categoryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(categoryIcon, color: categoryColor, size: 16),
                ),
                const SizedBox(width: 12),

                // Log Message
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        log['message'] ?? 'No message',
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
                          // Level Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: levelColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(levelIcon, size: 8, color: levelColor),
                                const SizedBox(width: 4),
                                Text(
                                  _formatLevelName(level),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: levelColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Category Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: categoryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _formatCategoryName(category),
                              style: TextStyle(
                                fontSize: 10,
                                color: categoryColor,
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
                            _formatTimestamp(log['timestamp']),
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

  Color _getLevelColor(String level) {
    switch (level) {
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

  String _formatCategoryName(String category) {
    switch (category) {
      case 'authentication':
        return 'Authentication';
      case 'accountManagement':
        return 'Account Management';
      case 'budgetManagement':
        return 'Budget Management';
      case 'expenseManagement':
        return 'Expense Management';
      case 'system':
        return 'System';
      case 'userAction':
        return 'User Action';
      case 'error':
        return 'Error';
      case 'performance':
        return 'Performance';
      case 'security':
        return 'Security';
      default:
        return category;
    }
  }

  @override
  Widget build(BuildContext context) {
    final level = log['level'] ?? 'info';
    final category = log['category'] ?? 'unknown';
    final color = _getLevelColor(level);

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
            _buildDetailRow('Message', log['message'] ?? 'No message'),
            _buildDetailRow('Level', (log['level'] ?? 'info').toUpperCase()),
            _buildDetailRow('Category', _formatCategoryName(category)),
            _buildDetailRow('Log ID', log['log_id'] ?? 'Unknown'),
            _buildDetailRow('Timestamp', _formatTimestamp(log['timestamp'])),
            _buildDetailRow('User', log['user_name'] ?? 'System'),
            if (log['user_email'] != null && log['user_email'] != 'N/A')
              _buildDetailRow('Email', log['user_email']),
            if (log['user_role'] != null && log['user_role'] != 'N/A')
              _buildDetailRow('Role', log['user_role']),
            if (log['company_id'] != null)
              _buildDetailRow('Company ID', log['company_id']),
            if (log['data'] != null)
              _buildDetailRow('Additional Data', log['data'].toString()),
            if (log['stack_trace'] != null)
              _buildDetailRow('Stack Trace', log['stack_trace']),
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
            child: Text(
              value,
              style: TextStyle(color: AppTheme.textPrimary),
              maxLines:
                  label == 'Stack Trace' || label == 'Additional Data' ? 10 : 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
