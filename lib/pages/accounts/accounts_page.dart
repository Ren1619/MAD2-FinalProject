import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/firebase_auth_service.dart';
import '../../services/firebase_logs_service.dart';
import '../../widgets/common_widgets.dart';
import '../../theme.dart';
import 'account_details_page.dart';

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
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<FirebaseAuthService>(
        context,
        listen: false,
      );
      final userData = await authService.currentUser;

      print('Current user data: $userData'); // Debug log

      if (userData != null) {
        final companyId = userData['company_id'];
        print('Loading accounts for company: $companyId'); // Debug log

        final accounts = await authService.getAccountsByCompany(companyId);
        print('Loaded ${accounts.length} accounts: $accounts'); // Debug log

        setState(() {
          _accounts = accounts;
          _filteredAccounts = accounts;
          _isLoading = false;

          // Reset filters when loading accounts
          _searchQuery = '';
          _statusFilter = 'All';
          _roleFilter = 'All';
        });

        // Don't apply filters immediately, let user see all accounts first
        // _applyFilters();
      } else {
        print('No user data found');
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error in _loadAccounts: $e'); // Debug log
      setState(() => _isLoading = false);
      _showErrorSnackBar('Error loading accounts: $e');
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
          (context) => _CreateAccountDialog(
            onAccountCreated: () {
              Navigator.pop(context);
              _loadAccounts();
            },
          ),
    );
  }

  void _showEditAccountDialog(Map<String, dynamic> account) {
    showDialog(
      context: context,
      builder:
          (context) => _EditAccountDialog(
            account: account,
            onAccountUpdated: () {
              Navigator.pop(context);
              _loadAccounts();
            },
          ),
    );
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

  @override
  Widget build(BuildContext context) {
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

                        // Filter Row with proper styling
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
                                // Remove custom style from the field itself
                                items:
                                    _statusOptions.map((status) {
                                      return DropdownMenuItem(
                                        value: status,
                                        child: Text(
                                          status,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color:
                                                AppTheme
                                                    .textPrimary, // Ensure text is visible
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
                                // Remove custom style from the field itself
                                items:
                                    _roleOptions.map((role) {
                                      // Shorten the role names for display
                                      String displayRole = role;
                                      if (role ==
                                          'Financial Planning and Budgeting Officer') {
                                        displayRole = 'Financial Officer';
                                      }

                                      return DropdownMenuItem(
                                        value: role,
                                        child: Text(
                                          displayRole,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color:
                                                AppTheme
                                                    .textPrimary, // Ensure text is visible
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
                            const SizedBox(width: 8),

                            // Create Account Button
                            ElevatedButton.icon(
                              onPressed: _showCreateAccountDialog,
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text(
                                'Create',
                                style: TextStyle(fontSize: 14),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                minimumSize: const Size(80, 36),
                              ),
                            ),
                          ],
                        ),
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
                              // Remove the action button from empty state
                              // onActionPressed: null,
                              // actionLabel: null,
                            )
                            : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _filteredAccounts.length,
                              itemBuilder: (context, index) {
                                final account = _filteredAccounts[index];
                                return _buildAccountCard(account);
                              },
                            ),
                  ),
                ],
              ),
    );
  }

  Widget _buildAccountCard(Map<String, dynamic> account) {
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
            Row(
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
                const SizedBox(width: 16),
                // Name and Email
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${account['f_name']} ${account['l_name']}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        account['email'] ?? '',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Status and Role
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    StatusBadge(status: account['status'] ?? 'Unknown'),
                    const SizedBox(height: 4),
                    RoleBadge(role: account['role'] ?? 'Unknown'),
                  ],
                ),
              ],
            ),

            if (account['contact_number']?.isNotEmpty ?? false) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.phone, size: 16, color: AppTheme.textSecondary),
                  const SizedBox(width: 8),
                  Text(
                    account['contact_number'],
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 16),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _viewAccountDetails(account),
                    icon: const Icon(Icons.visibility, size: 16),
                    label: const Text('View Details'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        isAdmin ? null : () => _showEditAccountDialog(account),
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Edit'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        isAdmin ? null : () => _toggleAccountStatus(account),
                    icon: Icon(
                      isActive ? Icons.block : Icons.check_circle,
                      size: 16,
                    ),
                    label: Text(isActive ? 'Disable' : 'Enable'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isActive ? Colors.orange : Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: isAdmin ? null : () => _deleteAccount(account),
                  icon: const Icon(Icons.delete),
                  color: Colors.red,
                  tooltip: 'Delete Account',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Create Account Dialog
class _CreateAccountDialog extends StatefulWidget {
  final VoidCallback onAccountCreated;

  const _CreateAccountDialog({required this.onAccountCreated});

  @override
  State<_CreateAccountDialog> createState() => _CreateAccountDialogState();
}

class _CreateAccountDialogState extends State<_CreateAccountDialog> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String _selectedRole = 'Budget Manager';
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _createAccount() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<FirebaseAuthService>(
        context,
        listen: false,
      );
      final userData = await authService.currentUser;
      print('Admin user data: $userData'); // Debug log

      if (userData != null) {
        final companyId = userData['company_id'];
        final adminEmail = userData['email'];
        print('Creating account with company_id: $companyId'); // Debug log

        // Create the account
        final success = await authService.createUserAccount(
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text,
          role: _selectedRole,
          phone: _phoneController.text.trim(),
          companyId: companyId,
        );

        if (success) {
          // Account created successfully, admin was signed out
          if (mounted) {
            // Close the create account dialog
            Navigator.pop(context);

            // Show re-authentication dialog
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) {
                _showReauthenticationDialog(adminEmail);
              }
            });
          }
        } else {
          // Account creation failed
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                  'Failed to create account. Please try again.',
                ),
                backgroundColor: Colors.red[700],
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      } else {
        throw 'Cannot get current user data';
      }
    } catch (e) {
      print('Error in _createAccount: $e'); // Debug log
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating account: $e'),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Show re-authentication dialog
  void _showReauthenticationDialog(String adminEmail) {
    final passwordController = TextEditingController();
    bool obscurePassword = true;
    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing without re-authentication
      builder:
          (BuildContext dialogContext) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 28),
                      const SizedBox(width: 12),
                      Text(
                        'Account Created!',
                        style: TextStyle(color: AppTheme.primaryColor),
                      ),
                    ],
                  ),
                  content: SizedBox(
                    width: 350,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green[200]!),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Colors.green[700],
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'The account has been created successfully!',
                                  style: TextStyle(
                                    color: Colors.green[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Please enter your admin password to continue managing accounts:',
                          style: TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: passwordController,
                          obscureText: obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Your Admin Password',
                            hintText: 'Enter your password',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: () {
                                setDialogState(
                                  () => obscurePassword = !obscurePassword,
                                );
                              },
                            ),
                          ),
                          autofocus: true,
                          onSubmitted: (_) {
                            if (passwordController.text.isNotEmpty &&
                                !isLoading) {
                              _handleReauthentication(
                                passwordController.text,
                                adminEmail,
                                setDialogState,
                                dialogContext,
                              );
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.lightbulb_outline,
                                color: Colors.blue[700],
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'This is required because creating an account signs you out temporarily.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue[700],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed:
                          isLoading
                              ? null
                              : () {
                                // If they cancel, redirect to login page
                                Navigator.of(context).pushNamedAndRemoveUntil(
                                  '/login',
                                  (route) => false,
                                );
                              },
                      child: const Text('Logout Instead'),
                    ),
                    ElevatedButton(
                      onPressed:
                          isLoading
                              ? null
                              : () {
                                if (passwordController.text.isNotEmpty) {
                                  _handleReauthentication(
                                    passwordController.text,
                                    adminEmail,
                                    setDialogState,
                                    dialogContext,
                                  );
                                }
                              },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                      ),
                      child:
                          isLoading
                              ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                              : const Text('Continue'),
                    ),
                  ],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
          ),
    ).then((_) {
      // Clean up controller when dialog is closed
      passwordController.dispose();
    });
  }

  Future<void> _handleReauthentication(
    String password,
    String adminEmail,
    StateSetter setDialogState,
    BuildContext dialogContext,
  ) async {
    setDialogState(() {});
    bool isLoading = true;
    setDialogState(() {});

    try {
      final authService = Provider.of<FirebaseAuthService>(
        context,
        listen: false,
      );

      final success = await authService.reauthenticateAdmin(
        adminEmail,
        password,
      );

      if (success) {
        Navigator.pop(dialogContext); // Close re-auth dialog
        widget.onAccountCreated();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                const Text('Account created and signed back in successfully!'),
              ],
            ),
            backgroundColor: Colors.green[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Invalid password. Please try again.'),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } finally {
      isLoading = false;
      setDialogState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Create New Account',
        style: TextStyle(color: AppTheme.primaryColor),
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
        child: IntrinsicHeight(
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // First and Last Name Row
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _firstNameController,
                          decoration: const InputDecoration(
                            labelText: 'First Name',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            isDense: true,
                          ),
                          validator: (value) {
                            if (value?.trim().isEmpty ?? true) {
                              return 'First name is required';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _lastNameController,
                          decoration: const InputDecoration(
                            labelText: 'Last Name',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            isDense: true,
                          ),
                          validator: (value) {
                            if (value?.trim().isEmpty ?? true) {
                              return 'Last name is required';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Email Address
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email Address',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value?.trim().isEmpty ?? true) {
                        return 'Email is required';
                      }
                      if (!RegExp(
                        r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                      ).hasMatch(value!)) {
                        return 'Enter a valid email address';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Phone Number
                  TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number (Optional)',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),

                  // Role Dropdown
                  Container(
                    width: double.infinity,
                    child: DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Role',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        isDense: true,
                      ),
                      value: _selectedRole,
                      isExpanded: true,
                      items:
                          FirebaseAuthService.getAvailableRoles().map((role) {
                            String displayRole = role;
                            if (role ==
                                'Financial Planning and Budgeting Officer') {
                              displayRole = 'Financial Officer';
                            }

                            return DropdownMenuItem(
                              value: role,
                              child: Text(
                                displayRole,
                                style: const TextStyle(fontSize: 14),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            );
                          }).toList(),
                      onChanged: (value) {
                        setState(() => _selectedRole = value!);
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select a role';
                        }
                        return null;
                      },
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Password
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      isDense: true,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          size: 20,
                        ),
                        onPressed: () {
                          setState(() => _obscurePassword = !_obscurePassword);
                        },
                      ),
                    ),
                    obscureText: _obscurePassword,
                    validator: (value) {
                      if (value?.isEmpty ?? true) {
                        return 'Password is required';
                      }
                      if (value!.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Confirm Password
                  TextFormField(
                    controller: _confirmPasswordController,
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      isDense: true,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          size: 20,
                        ),
                        onPressed: () {
                          setState(
                            () =>
                                _obscureConfirmPassword =
                                    !_obscureConfirmPassword,
                          );
                        },
                      ),
                    ),
                    obscureText: _obscureConfirmPassword,
                    validator: (value) {
                      if (value != _passwordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _createAccount,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
          ),
          child:
              _isLoading
                  ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                  : const Text('Create Account'),
        ),
      ],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }
}

// Edit Account Dialog
class _EditAccountDialog extends StatefulWidget {
  final Map<String, dynamic> account;
  final VoidCallback onAccountUpdated;

  const _EditAccountDialog({
    required this.account,
    required this.onAccountUpdated,
  });

  @override
  State<_EditAccountDialog> createState() => _EditAccountDialogState();
}

class _EditAccountDialogState extends State<_EditAccountDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(
      text: widget.account['f_name'] ?? '',
    );
    _lastNameController = TextEditingController(
      text: widget.account['l_name'] ?? '',
    );
    _emailController = TextEditingController(
      text: widget.account['email'] ?? '',
    );
    _phoneController = TextEditingController(
      text: widget.account['contact_number'] ?? '',
    );
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _updateAccount() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<FirebaseAuthService>(
        context,
        listen: false,
      );

      final updates = {
        'f_name': _firstNameController.text.trim(),
        'l_name': _lastNameController.text.trim(),
        'contact_number': _phoneController.text.trim(),
      };

      final success = await authService.updateUserProfile(
        widget.account['account_id'],
        updates,
      );

      if (success) {
        widget.onAccountUpdated();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Account updated successfully'),
            backgroundColor: Colors.green[700],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating account: $e'),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Edit Account',
        style: TextStyle(color: AppTheme.primaryColor),
      ),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _firstNameController,
                      decoration: const InputDecoration(
                        labelText: 'First Name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value?.trim().isEmpty ?? true) {
                          return 'First name is required';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _lastNameController,
                      decoration: const InputDecoration(
                        labelText: 'Last Name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value?.trim().isEmpty ?? true) {
                          return 'Last name is required';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email Address',
                  border: OutlineInputBorder(),
                ),
                enabled: false, // Email cannot be changed
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Role: ${widget.account['role']}\nEmail and role cannot be changed.',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _updateAccount,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
          ),
          child:
              _isLoading
                  ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                  : const Text(
                    'Update Account',
                    style: TextStyle(color: Colors.white),
                  ),
        ),
      ],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }
}
