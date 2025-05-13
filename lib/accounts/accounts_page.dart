import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/database_service.dart';
import '../widgets/common_widgets.dart';
import './create_account_dialog.dart';

class AccountsPage extends StatefulWidget {
  const AccountsPage({Key? key}) : super(key: key);

  @override
  AccountsPageState createState() => AccountsPageState();
}

class AccountsPageState extends State<AccountsPage> {
  late DatabaseService _databaseService;
  bool _isLoading = true;
  List<Map<String, dynamic>> _accounts = [];
  String _searchQuery = '';
  String _filterType = "All";

  // Add refresh indicator key
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey =
      GlobalKey<RefreshIndicatorState>();

  @override
  void initState() {
    super.initState();
    // fetchAccounts will be called in didChangeDependencies
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Get the database service from provider
    _databaseService = Provider.of<DatabaseService>(context);
    _fetchAccounts();
  }

  // Filter accounts based on search query
  List<Map<String, dynamic>> get _filteredAccounts {
    if (_searchQuery.isEmpty && _filterType == "All") {
      return _accounts;
    }

    return _accounts.where((account) {
      // Apply search query filter
      bool matchesSearch = true;
      if (_searchQuery.isNotEmpty) {
        final name = account['name']?.toString().toLowerCase() ?? '';
        final email = account['email']?.toString().toLowerCase() ?? '';
        final role = account['role']?.toString().toLowerCase() ?? '';
        final query = _searchQuery.toLowerCase();

        matchesSearch =
            name.contains(query) ||
            email.contains(query) ||
            role.contains(query);
      }

      // Apply role/status filter
      bool matchesFilter = true;
      if (_filterType != "All") {
        if (_filterType == "Active" || _filterType == "Inactive") {
          matchesFilter = account['status'] == _filterType;
        } else if (_filterType == "budget_manager") {
          matchesFilter = account['role'] == "Budget Manager";
        } else if (_filterType == "fp_manager") {
          matchesFilter =
              account['role'] == "Financial Planning and Analysis Manager";
        } else if (_filterType == "spender") {
          matchesFilter = account['role'] == "Authorized Spender";
        }
      }

      return matchesSearch && matchesFilter;
    }).toList();
  }

  // Handle user status change
  Future<void> _handleUserStatusChange(
    String userId,
    String currentStatus,
  ) async {
    // Toggle between Active and Inactive
    final newStatus = currentStatus == 'Active' ? 'Inactive' : 'Active';

    try {
      await _databaseService.updateUserStatus(userId, newStatus);

      // Force refresh accounts list
      _fetchAccounts();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('User status updated to $newStatus')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating user status: ${e.toString()}')),
      );
    }
  }

  // Delete user account
  Future<void> _handleUserDelete(String userId) async {
    try {
      bool success = await _databaseService.deleteUser(userId);

      if (success) {
        // Refresh accounts list
        _fetchAccounts();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account deleted successfully')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete account')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting user: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DatabaseService>(
      builder: (context, databaseService, child) {
        return RefreshIndicator(
          key: _refreshIndicatorKey,
          onRefresh: _fetchAccounts,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search and filter row with responsive layout
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth < 600) {
                      // Mobile layout - stacked
                      return Column(
                        children: [
                          CustomSearchField(
                            hintText: 'Search accounts...',
                            onChanged: (value) {
                              setState(() {
                                _searchQuery = value;
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [_buildFilterButton(context)],
                          ),
                        ],
                      );
                    } else {
                      // Desktop/tablet layout - row layout
                      return Row(
                        children: [
                          Expanded(
                            child: CustomSearchField(
                              hintText: 'Search accounts...',
                              onChanged: (value) {
                                setState(() {
                                  _searchQuery = value;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          _buildFilterButton(context),
                        ],
                      );
                    }
                  },
                ),

                const SizedBox(height: 20),

                // Account cards with responsive list
                Expanded(
                  child:
                      _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _filteredAccounts.isEmpty
                          ? EmptyStateWidget(
                            message: 'No accounts found',
                            icon: Icons.person_off,
                            actionLabel: 'Create Account',
                            onActionPressed:
                                () => _showCreateAccountDialogWithRefresh(
                                  context,
                                ),
                          )
                          : LayoutBuilder(
                            builder: (context, constraints) {
                              if (constraints.maxWidth < 600) {
                                // Mobile layout - simplified cards
                                return ListView.builder(
                                  itemCount: _filteredAccounts.length,
                                  itemBuilder: (context, index) {
                                    final account = _filteredAccounts[index];
                                    return _buildMobileAccountCard(
                                      context,
                                      account,
                                    );
                                  },
                                );
                              } else if (constraints.maxWidth < 960) {
                                // Tablet layout - more detailed but still compact
                                return ListView.builder(
                                  itemCount: _filteredAccounts.length,
                                  itemBuilder: (context, index) {
                                    final account = _filteredAccounts[index];
                                    return _buildTabletAccountCard(
                                      context,
                                      account,
                                    );
                                  },
                                );
                              } else {
                                // Desktop layout - full details
                                return ListView.builder(
                                  itemCount: _filteredAccounts.length,
                                  itemBuilder: (context, index) {
                                    final account = _filteredAccounts[index];
                                    return _buildDesktopAccountCard(
                                      context,
                                      account,
                                    );
                                  },
                                );
                              }
                            },
                          ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Custom wrapper for create account dialog that ensures refresh
  void _showCreateAccountDialogWithRefresh(BuildContext context) {
    showCreateAccountDialog(
      context,
      onAccountCreated: () {
        _fetchAccounts();
      },
    );
  }

  // Filter button Widget
  Widget _buildFilterButton(BuildContext context) {
    return PopupMenuButton(
      icon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min, // Important for narrow screens
          children: [
            Icon(Icons.filter_list, color: Colors.blue[700]),
            const SizedBox(width: 4),
            Text(
              _filterType == "All" ? 'Filter' : 'Filter: $_filterType',
              style: TextStyle(color: Colors.blue[700]),
            ),
          ],
        ),
      ),
      itemBuilder:
          (context) => [
            const PopupMenuItem(value: 'All', child: Text('All Accounts')),
            const PopupMenuItem(
              value: 'budget_manager',
              child: Text('Budget Managers'),
            ),
            const PopupMenuItem(
              value: 'fp_manager',
              child: Text('Financial Planning Managers'),
            ),
            const PopupMenuItem(
              value: 'spender',
              child: Text('Authorized Spenders'),
            ),
            const PopupMenuItem(value: 'Active', child: Text('Active')),
            const PopupMenuItem(value: 'Inactive', child: Text('Inactive')),
          ],
      onSelected: (value) {
        setState(() {
          _filterType = value.toString();
        });
      },
    );
  }

  // Fetch accounts with current filter
  Future<void> _fetchAccounts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      _accounts = await _databaseService.fetchUsers();
    } catch (e) {
      print('Error fetching accounts: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Mobile account card - simplified for small screens
  Widget _buildMobileAccountCard(
    BuildContext context,
    Map<String, dynamic> account,
  ) {
    final String name = account['name'] ?? 'Unknown';
    final String email = account['email'] ?? 'No email';
    final String role = account['role'] ?? 'No role';
    final String status = account['status'] ?? 'Inactive';
    final String id = account['id'] ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blue[100],
                  child: Text(
                    name.isNotEmpty ? name.substring(0, 1) : 'U',
                    style: TextStyle(
                      color: Colors.blue[800],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        email,
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                PopupMenuButton(
                  icon: Icon(Icons.more_vert, color: Colors.grey[600]),
                  itemBuilder: (context) => _buildMenuItems(account),
                  onSelected: (value) async {
                    if (value == 'activate' || value == 'deactivate') {
                      await _handleUserStatusChange(id, status);
                    } else if (value == 'delete') {
                      // Show confirmation dialog before deleting
                      _showDeleteConfirmationDialog(context, id, name);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(child: RoleBadge(role: role)),
                const SizedBox(width: 8),
                StatusBadge(status: status),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Tablet account card - more details, still compact
  Widget _buildTabletAccountCard(
    BuildContext context,
    Map<String, dynamic> account,
  ) {
    final String name = account['name'] ?? 'Unknown';
    final String email = account['email'] ?? 'No email';
    final String role = account['role'] ?? 'No role';
    final String status = account['status'] ?? 'Inactive';
    final String id = account['id'] ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.blue[100],
              child: Text(
                name.isNotEmpty ? name.substring(0, 1) : 'U',
                style: TextStyle(
                  color: Colors.blue[800],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    email,
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Flexible(child: RoleBadge(role: role)),
                  const SizedBox(width: 12),
                  StatusBadge(status: status),
                  PopupMenuButton(
                    icon: Icon(Icons.more_vert, color: Colors.grey[600]),
                    itemBuilder: (context) => _buildMenuItems(account),
                    onSelected: (value) async {
                      if (value == 'activate' || value == 'deactivate') {
                        await _handleUserStatusChange(id, status);
                      } else if (value == 'delete') {
                        _showDeleteConfirmationDialog(context, id, name);
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Desktop account card - full details
  Widget _buildDesktopAccountCard(
    BuildContext context,
    Map<String, dynamic> account,
  ) {
    final String name = account['name'] ?? 'Unknown';
    final String email = account['email'] ?? 'No email';
    final String role = account['role'] ?? 'No role';
    final String status = account['status'] ?? 'Inactive';
    final String id = account['id'] ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.blue[100],
              child: Text(
                name.isNotEmpty ? name.substring(0, 1) : 'U',
                style: TextStyle(
                  color: Colors.blue[800],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    email,
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: RoleBadge(role: role),
              ),
            ),
            StatusBadge(status: status),
            const SizedBox(width: 12),
            PopupMenuButton(
              icon: Icon(Icons.more_vert, color: Colors.grey[600]),
              itemBuilder: (context) => _buildMenuItems(account),
              onSelected: (value) async {
                if (value == 'activate' || value == 'deactivate') {
                  await _handleUserStatusChange(id, status);
                } else if (value == 'delete') {
                  _showDeleteConfirmationDialog(context, id, name);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // Common menu items for all layouts
  List<PopupMenuItem> _buildMenuItems(Map<String, dynamic> account) {
    final String status = account['status'] ?? 'Inactive';

    return [
      const PopupMenuItem(
        value: 'edit',
        child: Row(
          children: [
            Icon(Icons.edit, size: 18),
            SizedBox(width: 8),
            Text('Edit'),
          ],
        ),
      ),
      const PopupMenuItem(
        value: 'reset',
        child: Row(
          children: [
            Icon(Icons.lock_reset, size: 18),
            SizedBox(width: 8),
            Text('Reset Password'),
          ],
        ),
      ),
      PopupMenuItem(
        value: status == 'Active' ? 'deactivate' : 'activate',
        child: Row(
          children: [
            Icon(
              status == 'Active' ? Icons.block : Icons.check_circle,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(status == 'Active' ? 'Deactivate' : 'Activate'),
          ],
        ),
      ),
      const PopupMenuItem(
        value: 'delete',
        child: Row(
          children: [
            Icon(Icons.delete, size: 18, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete', style: TextStyle(color: Colors.red)),
          ],
        ),
      ),
    ];
  }

  // Show confirmation dialog before deleting a user
  void _showDeleteConfirmationDialog(
    BuildContext context,
    String userId,
    String userName,
  ) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirm Deletion'),
            content: Text(
              'Are you sure you want to delete $userName? This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey[700]),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () async {
                  Navigator.pop(context);
                  // Call the delete method
                  await _handleUserDelete(userId);
                },
                child: const Text('Delete'),
              ),
            ],
          ),
    );
  }
}
