import 'package:flutter/material.dart';
import '../widgets/common_widgets.dart';
import 'package:intl/intl.dart';

class LogsPage extends StatefulWidget {
  const LogsPage({super.key});

  @override
  _LogsPageState createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _filterType = "All";
  bool _isLoading = false;

  // Sample data for logs
  final List<Map<String, dynamic>> _logs = [
    {
      'description': 'User login: admin@example.com',
      'timestamp': DateTime.now().subtract(const Duration(minutes: 5)),
      'type': 'Authentication',
      'user': 'Admin',
      'ip': '192.168.1.1',
    },
    {
      'description': 'New account created: john.doe@example.com',
      'timestamp': DateTime.now().subtract(const Duration(hours: 2)),
      'type': 'Account Management',
      'user': 'Admin',
      'ip': '192.168.1.1',
    },
    {
      'description': 'Budget approved: Marketing Q2 Campaign',
      'timestamp': DateTime.now().subtract(
        const Duration(hours: 3, minutes: 15),
      ),
      'type': 'Budget',
      'user': 'Jane Smith',
      'ip': '192.168.1.45',
    },
    {
      'description': 'Password reset requested for: sarah@example.com',
      'timestamp': DateTime.now().subtract(
        const Duration(hours: 5, minutes: 32),
      ),
      'type': 'Authentication',
      'user': 'System',
      'ip': '192.168.1.22',
    },
    {
      'description': 'Budget revision requested: Office Supplies Monthly',
      'timestamp': DateTime.now().subtract(
        const Duration(hours: 7, minutes: 12),
      ),
      'type': 'Budget',
      'user': 'Robert Brown',
      'ip': '192.168.1.78',
    },
    {
      'description':
          'User account status changed: mike@example.com (Deactivated)',
      'timestamp': DateTime.now().subtract(const Duration(days: 1, hours: 2)),
      'type': 'Account Management',
      'user': 'Admin',
      'ip': '192.168.1.1',
    },
    {
      'description': 'Budget denied: Executive Retreat Planning',
      'timestamp': DateTime.now().subtract(const Duration(days: 1, hours: 6)),
      'type': 'Budget',
      'user': 'Jane Smith',
      'ip': '192.168.1.45',
    },
    {
      'description': 'System backup completed',
      'timestamp': DateTime.now().subtract(const Duration(days: 1, hours: 23)),
      'type': 'System',
      'user': 'System',
      'ip': '192.168.1.1',
    },
    {
      'description': 'New budget submitted: Q3 Marketing Campaign',
      'timestamp': DateTime.now().subtract(const Duration(days: 2, hours: 4)),
      'type': 'Budget',
      'user': 'Mike Johnson',
      'ip': '192.168.1.33',
    },
    {
      'description': 'Password changed: jane.smith@example.com',
      'timestamp': DateTime.now().subtract(const Duration(days: 2, hours: 9)),
      'type': 'Authentication',
      'user': 'Jane Smith',
      'ip': '192.168.1.45',
    },
    {
      'description': 'System update installed: v2.1.5',
      'timestamp': DateTime.now().subtract(const Duration(days: 3)),
      'type': 'System',
      'user': 'System',
      'ip': '192.168.1.1',
    },
    {
      'description': 'Budget archived: Holiday Party 2024',
      'timestamp': DateTime.now().subtract(const Duration(days: 4, hours: 12)),
      'type': 'Budget',
      'user': 'Admin',
      'ip': '192.168.1.1',
    },
    {
      'description': 'Failed login attempt: unknown@example.com',
      'timestamp': DateTime.now().subtract(const Duration(days: 5, hours: 3)),
      'type': 'Authentication',
      'user': 'Unknown',
      'ip': '192.168.1.100',
    },
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Format timestamp
  String _formatTimestamp(DateTime timestamp) {
    // Same day - show time only
    if (timestamp.day == DateTime.now().day &&
        timestamp.month == DateTime.now().month &&
        timestamp.year == DateTime.now().year) {
      return 'Today, ${DateFormat.jm().format(timestamp)}';
    }

    // Yesterday
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    if (timestamp.day == yesterday.day &&
        timestamp.month == yesterday.month &&
        timestamp.year == yesterday.year) {
      return 'Yesterday, ${DateFormat.jm().format(timestamp)}';
    }

    // Current year
    if (timestamp.year == DateTime.now().year) {
      return DateFormat('MMM d, ').add_jm().format(timestamp);
    }

    // Different year
    return DateFormat('MMM d, y, ').add_jm().format(timestamp);
  }

  // Get color for log type
  Color _getTypeColor(String type) {
    switch (type) {
      case 'Authentication':
        return Colors.blue;
      case 'Account Management':
        return Colors.purple;
      case 'Budget':
        return Colors.green;
      case 'System':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  // Get filtered logs
  List<Map<String, dynamic>> _getFilteredLogs() {
    List<Map<String, dynamic>> filteredList = [];

    String searchQuery = _searchController.text.toLowerCase();

    for (var log in _logs) {
      // Filter by type
      if (_filterType == "All" || log['type'] == _filterType) {
        // Filter by search query
        if (searchQuery.isEmpty ||
            log['description'].toLowerCase().contains(searchQuery) ||
            log['user'].toLowerCase().contains(searchQuery) ||
            log['ip'].toLowerCase().contains(searchQuery)) {
          filteredList.add(log);
        }
      }
    }

    // Sort by timestamp (newest first)
    filteredList.sort(
      (a, b) =>
          (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime),
    );

    return filteredList;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title and description
            Text(
              'Activity Logs',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.blue[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Review all activity in the system',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            const SizedBox(height: 16),

            // Search and filter section
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 600) {
                  // Mobile layout - stacked
                  return Column(
                    children: [
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search logs...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          contentPadding: EdgeInsets.zero,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [_buildFilterDropdown()],
                      ),
                    ],
                  );
                } else {
                  // Desktop/tablet layout
                  return Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search logs...',
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            contentPadding: EdgeInsets.zero,
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 16),
                      _buildFilterDropdown(),
                    ],
                  );
                }
              },
            ),

            const SizedBox(height: 16),

            // Export and refresh buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.file_download),
                  label: const Text('Export'),
                  onPressed: () {
                    // Export functionality would go here
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Logs exported to CSV')),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue[700],
                    side: BorderSide(color: Colors.blue[300]!),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh',
                  onPressed: () {
                    setState(() {
                      _isLoading = true;
                    });

                    // Simulate refresh delay
                    Future.delayed(const Duration(milliseconds: 800), () {
                      setState(() {
                        _isLoading = false;
                      });
                    });
                  },
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Log entries list
            Expanded(
              child:
                  _isLoading
                      ? const LoadingIndicator(message: 'Loading logs...')
                      : _buildLogsList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButton<String>(
        value: _filterType,
        icon: Icon(Icons.filter_list, color: Colors.blue[700]),
        underline: const SizedBox(),
        items: const [
          DropdownMenuItem(value: 'All', child: Text('All Events')),
          DropdownMenuItem(
            value: 'Authentication',
            child: Text('Authentication'),
          ),
          DropdownMenuItem(
            value: 'Account Management',
            child: Text('Account Management'),
          ),
          DropdownMenuItem(value: 'Budget', child: Text('Budget')),
          DropdownMenuItem(value: 'System', child: Text('System')),
        ],
        onChanged: (value) {
          setState(() {
            _filterType = value!;
          });
        },
      ),
    );
  }

  Widget _buildLogsList() {
    final filteredLogs = _getFilteredLogs();

    if (filteredLogs.isEmpty) {
      return EmptyStateWidget(message: 'No logs found', icon: Icons.search_off);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Choose layout based on screen width
        if (constraints.maxWidth < 600) {
          return _buildMobileLogsList(filteredLogs);
        } else {
          return _buildDesktopLogsList(filteredLogs);
        }
      },
    );
  }

  Widget _buildMobileLogsList(List<Map<String, dynamic>> logs) {
    return ListView.separated(
      itemCount: logs.length,
      separatorBuilder: (context, index) => const Divider(),
      itemBuilder: (context, index) {
        final log = logs[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            vertical: 8,
            horizontal: 12,
          ),
          leading: CircleAvatar(
            backgroundColor: _getTypeColor(log['type']).withOpacity(0.2),
            child: Icon(
              _getLogIcon(log['type']),
              color: _getTypeColor(log['type']),
              size: 20,
            ),
          ),
          title: Text(
            log['description'],
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                _formatTimestamp(log['timestamp']),
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              Text(
                'User: ${log['user']} • IP: ${log['ip']}',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),
          trailing: IconButton(
            icon: const Icon(Icons.info_outline, size: 20),
            onPressed: () => _showLogDetails(context, log),
          ),
        );
      },
    );
  }

  Widget _buildDesktopLogsList(List<Map<String, dynamic>> logs) {
    return SingleChildScrollView(
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: DataTable(
            columnSpacing: 16,
            horizontalMargin: 12,
            dataRowHeight: 60,
            columns: const [
              DataColumn(
                label: Text(
                  'Event',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  'User',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  'IP Address',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  'Timestamp',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  'Details',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
            rows:
                logs.map((log) {
                  return DataRow(
                    cells: [
                      DataCell(
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: _getTypeColor(
                                log['type'],
                              ).withOpacity(0.2),
                              child: Icon(
                                _getLogIcon(log['type']),
                                color: _getTypeColor(log['type']),
                                size: 14,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    log['description'],
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    log['type'],
                                    style: TextStyle(
                                      color: _getTypeColor(log['type']),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      DataCell(Text(log['user'])),
                      DataCell(Text(log['ip'])),
                      DataCell(Text(_formatTimestamp(log['timestamp']))),
                      DataCell(
                        IconButton(
                          icon: const Icon(Icons.info_outline, size: 20),
                          onPressed: () => _showLogDetails(context, log),
                        ),
                      ),
                    ],
                  );
                }).toList(),
          ),
        ),
      ),
    );
  }

  IconData _getLogIcon(String type) {
    switch (type) {
      case 'Authentication':
        return Icons.security;
      case 'Account Management':
        return Icons.manage_accounts;
      case 'Budget':
        return Icons.account_balance_wallet;
      case 'System':
        return Icons.settings;
      default:
        return Icons.info;
    }
  }

  void _showLogDetails(BuildContext context, Map<String, dynamic> log) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              'Log Details',
              style: TextStyle(
                color: Colors.blue[800],
                fontWeight: FontWeight.bold,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow(
                    'Event Type',
                    log['type'],
                    _getTypeColor(log['type']),
                  ),
                  const SizedBox(height: 16),
                  _buildDetailRow('Description', log['description']),
                  const SizedBox(height: 16),
                  _buildDetailRow(
                    'Timestamp',
                    _formatTimestamp(log['timestamp']),
                  ),
                  const SizedBox(height: 16),
                  _buildDetailRow('User', log['user']),
                  const SizedBox(height: 16),
                  _buildDetailRow('IP Address', log['ip']),

                  // Additional information could be added here
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text(
                    'Additional Information',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Session ID: ${log.hashCode.toString()}',
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                  ),
                  Text(
                    'Event ID: LOG-${1000 + _logs.indexOf(log)}',
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Close', style: TextStyle(color: Colors.grey[700])),
              ),
            ],
          ),
    );
  }

  Widget _buildDetailRow(String label, String value, [Color? valueColor]) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            color: valueColor ?? Colors.grey[700],
            fontWeight:
                valueColor != null ? FontWeight.w500 : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
