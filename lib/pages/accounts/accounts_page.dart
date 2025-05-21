import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/firebase_auth_service.dart';
import '../../services/firebase_logs_service.dart';
import '../../widgets/common_widgets.dart';
import '../../theme.dart';
import 'account_details_page.dart';
import 'create_account_dialog.dart';
import 'edit_account_dialog.dart';

class AccountsPage extends StatefulWidget {
  final VoidCallback? onOpenDrawer;
  final Map<String, dynamic>? userData;

  const AccountsPage({super.key, this.onOpenDrawer, this.userData});
  @override
  State<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends State<AccountsPage> {
  List<Map<String, dynamic>> _accounts = [];
  List<Map<String, dynamic>> _filteredAccounts = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _statusFilter = 'All';
  String _roleFilter = 'All';

  final List<String> _statusOptions = ['All', 'Active', 'Inactive'];
  final List<String> _roleOptions = [
    'All',
    'Budget Manager',
    'Financial Planning and Budgeting Officer',
    'Authorized Spender',
  ];

  @override
  void initState() {
    super.initState();

    // Load accounts initially
    _loadAccounts();

    // Optional: Set up a periodic check for auth state
    // This helps catch cases where auth state changes unexpectedly
    Timer.periodic(const Duration(minutes: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final authService = Provider.of<FirebaseAuthService>(
        context,
        listen: false,
      );

      if (!authService.isSignedIn) {
        timer.cancel();
        Navigator.pushReplacementNamed(context, '/login');
      }
    });
  }

  Future<void> _loadAccounts() async {
    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<FirebaseAuthService>(
        context,
        listen: false,
      );

      // Check if user is signed in
      if (!authService.isSignedIn) {
        print('User not signed in, redirecting to login');
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }

      final userData = await authService.currentUser;
      print('Current user data: $userData'); // Debug log

      if (userData != null) {
        final companyId = userData['company_id'];
        print('Loading accounts for company: $companyId'); // Debug log

        final accounts = await authService.getAccountsByCompany(companyId);
        print('Loaded ${accounts.length} accounts'); // Debug log

        if (mounted) {
          setState(() {
            _accounts = accounts;
            _filteredAccounts = accounts;
            _isLoading = false;

            // Reset filters when loading accounts
            _searchQuery = '';
            _statusFilter = 'All';
            _roleFilter = 'All';
          });
        }
      } else {
        print('No user data found');
        if (mounted) {
          setState(() => _isLoading = false);
          // Redirect to login if no user data
          Navigator.pushReplacementNamed(context, '/login');
        }
      }
    } catch (e) {
      print('Error in _loadAccounts: $e'); // Debug log
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackBar('Error loading accounts: $e');
      }
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredAccounts =
          _accounts.where((account) {
            // Search filter
            if (_searchQuery.isNotEmpty) {
              final searchLower = _searchQuery.toLowerCase();
              final name =
                  '${account['f_name']} ${account['l_name']}'.toLowerCase();
              final email = (account['email'] ?? '').toLowerCase();

              if (!name.contains(searchLower) && !email.contains(searchLower)) {
                return false;
              }
            }

            // Status filter
            if (_statusFilter != 'All' && account['status'] != _statusFilter) {
              return false;
            }

            // Role filter
            if (_roleFilter != 'All' && account['role'] != _roleFilter) {
              return false;
            }

            return true;
          }).toList();
    });
  }

  void _showCreateAccountDialog() {
    showDialog(
      context: context,
      builder:
          (context) => CreateAccountDialog(
            onAccountCreated: () {
              // This will be called after successful account creation
              print('Account creation callback triggered');

              // Small delay to ensure Firestore has updated
              Future.delayed(const Duration(milliseconds: 500), () {
                if (mounted) {
                  _loadAccounts();
                }
              });
            },
          ),
    );
  }

  void _showEditAccountDialog(Map<String, dynamic> account) {
    showDialog(
      context: context,
      builder:
          (context) => EditAccountDialog(
            account: account,
            onAccountUpdated: () {
              Navigator.pop(context);
              _loadAccounts();
            },
          ),
    );
  }

  void _handleAuthStateChange() {
    final authService = Provider.of<FirebaseAuthService>(
      context,
      listen: false,
    );

    // Listen to auth state changes
    authService.currentFirebaseUser != null
        ? _loadAccounts()
        : Navigator.pushReplacementNamed(context, '/login');
  }

  void _viewAccountDetails(Map<String, dynamic> account) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AccountDetailsPage(account: account),
      ),
    ).then((_) => _loadAccounts());
  }

  void _toggleAccountStatus(Map<String, dynamic> account) async {
    try {
      final authService = Provider.of<FirebaseAuthService>(
        context,
        listen: false,
      );
      final newStatus = account['status'] == 'Active' ? 'Inactive' : 'Active';

      final success = await authService.updateUserStatus(
        account['account_id'],
        newStatus,
      );

      if (success) {
        _showSuccessSnackBar('Account status updated successfully');
        _loadAccounts();
      } else {
        _showErrorSnackBar('Failed to update account status');
      }
    } catch (e) {
      _showErrorSnackBar('Error updating account status: $e');
    }
  }

  void _deleteAccount(Map<String, dynamic> account) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              'Delete Account',
              style: TextStyle(color: Colors.red[700]),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Are you sure you want to delete this account?'),
                const SizedBox(height: 8),
                Text(
                  '${account['f_name']} ${account['l_name']} (${account['email']})',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'This action cannot be undone.',
                  style: TextStyle(color: Colors.red[600]),
                ),
              ],
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  try {
                    final authService = Provider.of<FirebaseAuthService>(
                      context,
                      listen: false,
                    );
                    final success = await authService.deleteUserAccount(
                      account['account_id'],
                    );

                    if (success) {
                      _showSuccessSnackBar('Account deleted successfully');
                      _loadAccounts();
                    } else {
                      _showErrorSnackBar('Failed to delete account');
                    }
                  } catch (e) {
                    _showErrorSnackBar('Error deleting account: $e');
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        action: SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: _loadAccounts,
        ),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1200;
    final isTablet = screenWidth > 768 && screenWidth <= 1200;

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: CustomAppBar(
        title: 'Account Management',
        onMenuPressed: widget.onOpenDrawer, // Pass the drawer function
        userData: widget.userData,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAccounts,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body:
          _isLoading
              ? const LoadingIndicator(message: 'Loading accounts...')
              : Column(
                children: [
                  // Filters and Search Section
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.white,
                    child: Column(
                      children: [
                        // Search Bar
                        CustomSearchField(
                          hintText: 'Search accounts by name or email...',
                          onChanged: (value) {
                            setState(() => _searchQuery = value);
                            _applyFilters();
                          },
                        ),
                        const SizedBox(height: 16),

                        // Filter Row with responsive layout
                        isDesktop
                            ? _buildDesktopFilterRow()
                            : _buildMobileFilterRow(),
                      ],
                    ),
                  ),
                  // Accounts List
                  Expanded(
                    child:
                        _filteredAccounts.isEmpty
                            ? EmptyStateWidget(
                              message:
                                  _searchQuery.isEmpty &&
                                          _statusFilter == 'All' &&
                                          _roleFilter == 'All'
                                      ? 'No accounts found.\nUse the "Create Account" button above to get started.'
                                      : 'No accounts match your search criteria.\nTry adjusting your filters or search terms.',
                              icon: Icons.people_outline,
                            )
                            : _buildAccountsList(isDesktop, isTablet),
                  ),
                ],
              ),
    );
  }

  Widget _buildDesktopFilterRow() {
    return Row(
      children: [
        // Status Filter
        SizedBox(
          width: 160,
          child: DropdownButtonFormField<String>(
            decoration: const InputDecoration(
              labelText: 'Status',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              isDense: true,
            ),
            value: _statusFilter,
            isExpanded: true,
            items:
                _statusOptions.map((status) {
                  return DropdownMenuItem(
                    value: status,
                    child: Text(
                      status,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  );
                }).toList(),
            onChanged: (value) {
              setState(() => _statusFilter = value!);
              _applyFilters();
            },
          ),
        ),
        const SizedBox(width: 16),

        // Role Filter
        SizedBox(
          width: 280,
          child: DropdownButtonFormField<String>(
            decoration: const InputDecoration(
              labelText: 'Role',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              isDense: true,
            ),
            value: _roleFilter,
            isExpanded: true,
            items:
                _roleOptions.map((role) {
                  return DropdownMenuItem(
                    value: role,
                    child: Text(
                      role,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  );
                }).toList(),
            onChanged: (value) {
              setState(() => _roleFilter = value!);
              _applyFilters();
            },
          ),
        ),
        const Spacer(),

        // Create Account Button
        ElevatedButton.icon(
          onPressed: _showCreateAccountDialog,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Create Account'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileFilterRow() {
    return Column(
      children: [
        Row(
          children: [
            // Status Filter
            Expanded(
              flex: 1,
              child: DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Status',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  isDense: true,
                ),
                value: _statusFilter,
                isExpanded: true,
                items:
                    _statusOptions.map((status) {
                      return DropdownMenuItem(
                        value: status,
                        child: Text(
                          status,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                onChanged: (value) {
                  setState(() => _statusFilter = value!);
                  _applyFilters();
                },
              ),
            ),
            const SizedBox(width: 8),

            // Role Filter
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Role',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  isDense: true,
                ),
                value: _roleFilter,
                isExpanded: true,
                items:
                    _roleOptions.map((role) {
                      // Shorten the role names for display
                      String displayRole = role;
                      if (role == 'Financial Planning and Budgeting Officer') {
                        displayRole = 'Financial Officer';
                      }

                      return DropdownMenuItem(
                        value: role,
                        child: Text(
                          displayRole,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                onChanged: (value) {
                  setState(() => _roleFilter = value!);
                  _applyFilters();
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Create Account Button on mobile
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _showCreateAccountDialog,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Create Account'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAccountsList(bool isDesktop, bool isTablet) {
    if (isDesktop) {
      // For desktop: Use a better spaced grid layout
      return GridView.builder(
        padding: const EdgeInsets.all(24),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: isTablet ? 1 : 2,
          mainAxisExtent: 200,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: _filteredAccounts.length,
        itemBuilder: (context, index) {
          final account = _filteredAccounts[index];
          return _buildDesktopAccountCard(account);
        },
      );
    } else {
      // For mobile: Keep the list view
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _filteredAccounts.length,
        itemBuilder: (context, index) {
          final account = _filteredAccounts[index];
          return _buildMobileAccountCard(account);
        },
      );
    }
  }

  Widget _buildDesktopAccountCard(Map<String, dynamic> account) {
    final isAdmin = account['role'] == 'Administrator';
    final isActive = account['status'] == 'Active';

    return Card(
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                isActive
                    ? Colors.green.withOpacity(0.3)
                    : Colors.red.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with avatar and badges - Improved layout
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppTheme.primaryLightColor,
                  child: Text(
                    '${account['f_name']?[0] ?? ''}${account['l_name']?[0] ?? ''}'
                        .toUpperCase(),
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${account['f_name'] ?? ''} ${account['l_name'] ?? ''}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        account['email'] ?? '',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Status and Role badges - Improved with flexible layout
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                StatusBadge(status: account['status'] ?? 'Unknown'),
                RoleBadge(role: account['role'] ?? 'Unknown'),
              ],
            ),

            // Contact info with proper overflow handling
            if (account['contact_number']?.isNotEmpty ?? false) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.phone, size: 16, color: AppTheme.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      account['contact_number'] ?? '',
                      style: TextStyle(color: AppTheme.textSecondary),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            ],

            const Spacer(),

            // Action buttons - Wrapped for better responsiveness
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              children: [
                SizedBox(
                  width: 70,
                  child: OutlinedButton(
                    onPressed: () => _viewAccountDetails(account),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    child: const Text(
                      'Details',
                      style: TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                SizedBox(
                  width: 60,
                  child: OutlinedButton(
                    onPressed:
                        isAdmin ? null : () => _showEditAccountDialog(account),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    child: const Text(
                      'Edit',
                      style: TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                SizedBox(
                  width: 80,
                  child: OutlinedButton(
                    onPressed:
                        isAdmin ? null : () => _toggleAccountStatus(account),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isActive ? Colors.orange : Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    child: Text(
                      isActive ? 'Disable' : 'Enable',
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: isAdmin ? null : () => _deleteAccount(account),
                  icon: const Icon(Icons.delete, size: 18),
                  color: Colors.red,
                  tooltip: 'Delete Account',
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileAccountCard(Map<String, dynamic> account) {
    final isAdmin = account['role'] == 'Administrator';
    final isActive = account['status'] == 'Active';

    return HoverCard(
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                isActive
                    ? Colors.green.withOpacity(0.3)
                    : Colors.red.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Improved header layout
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppTheme.primaryLightColor,
                  child: Text(
                    '${account['f_name']?[0] ?? ''}${account['l_name']?[0] ?? ''}'
                        .toUpperCase(),
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Name and Email
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${account['f_name'] ?? ''} ${account['l_name'] ?? ''}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        account['email'] ?? '',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),

                // Status and Role - Better spacing
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        constraints: const BoxConstraints(maxWidth: 120),
                        child: StatusBadge(
                          status: account['status'] ?? 'Unknown',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        constraints: const BoxConstraints(maxWidth: 120),
                        child: RoleBadge(role: account['role'] ?? 'Unknown'),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Contact info with proper overflow
            if (account['contact_number']?.isNotEmpty ?? false) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.phone, size: 16, color: AppTheme.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      account['contact_number'] ?? '',
                      style: TextStyle(color: AppTheme.textSecondary),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 16),

            // Action Buttons - Using SingleChildScrollView for horizontal scrolling if needed
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _viewAccountDetails(account),
                    icon: const Icon(Icons.visibility, size: 16),
                    label: const Text('View Details'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed:
                        isAdmin ? null : () => _showEditAccountDialog(account),
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Edit'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed:
                        isAdmin ? null : () => _toggleAccountStatus(account),
                    icon: Icon(
                      isActive ? Icons.block : Icons.check_circle,
                      size: 16,
                    ),
                    label: Text(isActive ? 'Disable' : 'Enable'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isActive ? Colors.orange : Colors.green,
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: isAdmin ? null : () => _deleteAccount(account),
                    icon: const Icon(Icons.delete, size: 20),
                    color: Colors.red,
                    tooltip: 'Delete Account',
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
