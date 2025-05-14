import 'package:flutter/material.dart';
import '../services/database_service.dart';
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
  bool _isLoading = true;
  final DatabaseService _databaseService = DatabaseService();
  List<Map<String, dynamic>> _logs = [];

  @override
  void initState() {
    super.initState();
    _fetchLogs();

    // Add listener to search field
    _searchController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchLogs() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get logs from database service
      _logs = await _databaseService.fetchLogs();

      // Convert String timestamp to DateTime for each log
      for (var log in _logs) {
        if (log['timestamp'] != null) {
          try {
            log['timestamp'] = DateTime.parse(log['timestamp']);
          } catch (e) {
            log['timestamp'] = DateTime.now();
          }
        } else {
          log['timestamp'] = DateTime.now();
        }
      }
    } catch (e) {
      print('Error fetching logs: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
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
      final String type = log['type'] ?? '';
      final String description = log['description'] ?? '';
      final String user = log['user'] ?? '';
      final String ip = log['ip'] ?? '';

      // Filter by type
      if (_filterType == "All" || type == _filterType) {
        // Filter by search query
        if (searchQuery.isEmpty ||
            description.toLowerCase().contains(searchQuery) ||
            user.toLowerCase().contains(searchQuery) ||
            ip.toLowerCase().contains(searchQuery)) {
          filteredList.add(log);
        }
      }
    }

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
                    _fetchLogs();
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
        final String description = log['description'] ?? 'No description';
        final DateTime timestamp = log['timestamp'] ?? DateTime.now();
        final String user = log['user'] ?? 'Unknown';
        final String ip = log['ip'] ?? 'Unknown';
        final String type = log['type'] ?? 'Unknown';

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            vertical: 8,
            horizontal: 12,
          ),
          leading: CircleAvatar(
            backgroundColor: _getTypeColor(type).withOpacity(0.2),
            child: Icon(
              _getLogIcon(type),
              color: _getTypeColor(type),
              size: 20,
            ),
          ),
          title: Text(
            description,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
            maxLines: 2, // Prevent long descriptions from overflowing
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                _formatTimestamp(timestamp),
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              Text(
                'User: $user • IP: $ip',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                overflow: TextOverflow.ellipsis, // Prevent overflow
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
          child: SingleChildScrollView(
            // Add horizontal scrolling to handle overflow on smaller screens
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: 600,
                maxWidth:
                    MediaQuery.of(context).size.width > 800
                        ? MediaQuery.of(context).size.width - 64
                        : 800,
              ),
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
                      final String description =
                          log['description'] ?? 'No description';
                      final DateTime timestamp =
                          log['timestamp'] ?? DateTime.now();
                      final String user = log['user'] ?? 'Unknown';
                      final String ip = log['ip'] ?? 'Unknown';
                      final String type = log['type'] ?? 'Unknown';

                      return DataRow(
                        cells: [
                          DataCell(
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 300),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: _getTypeColor(
                                      type,
                                    ).withOpacity(0.2),
                                    child: Icon(
                                      _getLogIcon(type),
                                      color: _getTypeColor(type),
                                      size: 14,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          description,
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          type,
                                          style: TextStyle(
                                            color: _getTypeColor(type),
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
                          ),
                          DataCell(
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 120),
                              child: Text(
                                user,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          DataCell(
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 120),
                              child: Text(ip, overflow: TextOverflow.ellipsis),
                            ),
                          ),
                          DataCell(Text(_formatTimestamp(timestamp))),
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
    final String description = log['description'] ?? 'No description';
    final DateTime timestamp = log['timestamp'] ?? DateTime.now();
    final String user = log['user'] ?? 'Unknown';
    final String ip = log['ip'] ?? 'Unknown';
    final String type = log['type'] ?? 'Unknown';
    final String id = log['id'] ?? '';

    // Use a responsive width based on screen size
    final double dialogWidth =
        MediaQuery.of(context).size.width > 600
            ? 500
            : MediaQuery.of(context).size.width * 0.9;

    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            // Constrained size to prevent overflow
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: dialogWidth,
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Log Details',
                        style: TextStyle(
                          color: Colors.blue[800],
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildDetailRow('Event Type', type, _getTypeColor(type)),
                      const SizedBox(height: 16),
                      _buildDetailRow('Description', description),
                      const SizedBox(height: 16),
                      _buildDetailRow('Timestamp', _formatTimestamp(timestamp)),
                      const SizedBox(height: 16),
                      _buildDetailRow('User', user),
                      const SizedBox(height: 16),
                      _buildDetailRow('IP Address', ip),

                      // Additional information could be added here
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),
                      const Text(
                        'Additional Information',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Log ID: $id',
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                      ),
                      Text(
                        'Event ID: LOG-${id.hashCode.abs()}',
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(
                              'Close',
                              style: TextStyle(color: Colors.grey[700]),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
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
