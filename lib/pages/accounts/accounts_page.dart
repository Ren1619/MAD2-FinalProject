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

class _AccountsPageState extends State<AccountsPage>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _accounts = [];
  List<Map<String, dynamic>> _filteredAccounts = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _statusFilter = 'All';
  String _roleFilter = 'All';
  Timer? _authCheckTimer;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

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

    // Initialize animation controller for transitions
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOutCubic,
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutQuart),
    );

    // Load accounts initially
    _loadAccounts();

    // Optional: Set up a periodic check for auth state
    _authCheckTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
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
    _animationController.reset();

    try {
      final authService = Provider.of<FirebaseAuthService>(
        context,
        listen: false,
      );

      if (!authService.isSignedIn) {
        print('User not signed in, redirecting to login');
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }

      final userData = await authService.currentUser;
      print('Current user data: $userData');

      if (userData != null) {
        final companyId = userData['company_id'];
        print('Loading accounts for company: $companyId');

        final accounts = await authService.getAccountsByCompany(companyId);
        print('Loaded ${accounts.length} accounts');

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

          // Staggered animation for better UX
          await Future.delayed(const Duration(milliseconds: 100));
          if (mounted) {
            _animationController.forward();
          }
        }
      } else {
        print('No user data found');
        if (mounted) {
          setState(() => _isLoading = false);
          Navigator.pushReplacementNamed(context, '/login');
        }
      }
    } catch (e) {
      print('Error in _loadAccounts: $e');
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
      barrierDismissible: false,
      builder:
          (context) => CreateAccountDialog(
            onAccountCreated: () {
              print('Account creation callback triggered');
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
      barrierDismissible: false,
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

    authService.currentFirebaseUser != null
        ? _loadAccounts()
        : Navigator.pushReplacementNamed(context, '/login');
  }

  void _viewAccountDetails(Map<String, dynamic> account) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder:
            (context, animation, secondaryAnimation) =>
                AccountDetailsPage(account: account),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOutCubic;

          var tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));

          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.red[700],
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Delete Account',
                  style: TextStyle(
                    color: Colors.red[700],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Are you sure you want to delete this account?',
                  style: TextStyle(fontSize: 16, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: AppTheme.primaryLightColor,
                        child: Text(
                          '${account['f_name']?[0] ?? ''}${account['l_name']?[0] ?? ''}'
                              .toUpperCase(),
                          style: TextStyle(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${account['f_name']} ${account['l_name']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              account['email'] ?? '',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.red[600],
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'This action cannot be undone.',
                          style: TextStyle(
                            color: Colors.red[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey[700],
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              ElevatedButton.icon(
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
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Delete'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
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
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.error_outline,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 5),
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
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.check_circle,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _resetFilters() {
    setState(() {
      _searchQuery = '';
      _statusFilter = 'All';
      _roleFilter = 'All';
    });
    _applyFilters();
  }

  // Device type detection for better responsive design
  bool get isDesktop => MediaQuery.of(context).size.width > 1200;
  bool get isTablet =>
      MediaQuery.of(context).size.width > 768 &&
      MediaQuery.of(context).size.width <= 1200;
  bool get isMobile => MediaQuery.of(context).size.width <= 768;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      appBar: _buildAppBar(),
      body: RefreshIndicator(
        onRefresh: _loadAccounts,
        color: AppTheme.primaryColor,
        strokeWidth: 2.5,
        child:
            _isLoading
                ? _buildSkeletonLoading()
                : Column(
                  children: [
                    _buildHeaderSection(),
                    Expanded(
                      child:
                          _filteredAccounts.isEmpty
                              ? _buildEmptyState()
                              : SlideTransition(
                                position: _slideAnimation,
                                child: FadeTransition(
                                  opacity: _fadeAnimation,
                                  child: _buildAccountsList(),
                                ),
                              ),
                    ),
                  ],
                ),
      ),
      floatingActionButton:
          isMobile && !_isLoading ? _buildFloatingActionButton() : null,
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(
        'Account Management',
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
          color: Colors.white,
        ),
      ),
      backgroundColor: AppTheme.primaryColor,
      elevation: 0,
      leading:
          widget.onOpenDrawer != null
              ? IconButton(
                icon: const Icon(Icons.menu, color: Colors.white),
                onPressed: widget.onOpenDrawer,
              )
              : null,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          onPressed: _loadAccounts,
          tooltip: 'Refresh',
          style: IconButton.styleFrom(
            backgroundColor: Colors.white.withOpacity(0.1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.help_outline_rounded, color: Colors.white),
          onPressed: () {
            // Show help dialog
          },
          tooltip: 'Help',
          style: IconButton.styleFrom(
            backgroundColor: Colors.white.withOpacity(0.1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        const SizedBox(width: 16),
      ],
    );
  }

  Widget _buildHeaderSection() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderTitle(),
          const SizedBox(height: 20),
          _buildSearchBar(),
          const SizedBox(height: 20),
          _buildFiltersSection(),
        ],
      ),
    );
  }

  Widget _buildHeaderTitle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Team Members',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${_filteredAccounts.length} account${_filteredAccounts.length == 1 ? '' : 's'} found',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        if (_hasActiveFilters())
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.filter_alt, size: 16, color: AppTheme.primaryColor),
                const SizedBox(width: 4),
                Text(
                  'Filtered',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  bool _hasActiveFilters() {
    return _searchQuery.isNotEmpty ||
        _statusFilter != 'All' ||
        _roleFilter != 'All';
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              _searchQuery.isNotEmpty
                  ? AppTheme.primaryColor.withOpacity(0.3)
                  : Colors.transparent,
        ),
      ),
      child: TextField(
        onChanged: (value) {
          setState(() => _searchQuery = value);
          _applyFilters();
        },
        decoration: InputDecoration(
          hintText: 'Search by name, email, or role...',
          prefixIcon: Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.search_rounded,
              size: 20,
              color: AppTheme.primaryColor,
            ),
          ),
          suffixIcon:
              _searchQuery.isNotEmpty
                  ? IconButton(
                    onPressed: () {
                      setState(() => _searchQuery = '');
                      _applyFilters();
                    },
                    icon: Icon(
                      Icons.clear_rounded,
                      color: AppTheme.textSecondary,
                    ),
                  )
                  : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
          hintStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
        ),
        style: TextStyle(fontSize: 15, color: AppTheme.textPrimary),
      ),
    );
  }

  Widget _buildFiltersSection() {
    if (isDesktop) {
      return _buildDesktopFilters();
    } else {
      return _buildMobileFilters();
    }
  }

  Widget _buildDesktopFilters() {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: _buildFilterDropdown(
            label: 'Status',
            value: _statusFilter,
            options: _statusOptions,
            onChanged: (value) {
              setState(() => _statusFilter = value!);
              _applyFilters();
            },
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 3,
          child: _buildFilterDropdown(
            label: 'Role',
            value: _roleFilter,
            options: _roleOptions,
            onChanged: (value) {
              setState(() => _roleFilter = value!);
              _applyFilters();
            },
          ),
        ),
        const SizedBox(width: 16),
        if (_hasActiveFilters())
          TextButton.icon(
            onPressed: _resetFilters,
            icon: const Icon(Icons.filter_alt_off_rounded, size: 18),
            label: const Text('Clear'),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.textSecondary,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        const Spacer(),
        _buildCreateButton(),
      ],
    );
  }

  Widget _buildMobileFilters() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildFilterDropdown(
                label: 'Status',
                value: _statusFilter,
                options: _statusOptions,
                onChanged: (value) {
                  setState(() => _statusFilter = value!);
                  _applyFilters();
                },
                isCompact: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: _buildFilterDropdown(
                label: 'Role',
                value: _roleFilter,
                options: _roleOptions,
                onChanged: (value) {
                  setState(() => _roleFilter = value!);
                  _applyFilters();
                },
                isCompact: true,
              ),
            ),
          ],
        ),
        if (_hasActiveFilters()) ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _resetFilters,
              icon: const Icon(Icons.filter_alt_off_rounded, size: 16),
              label: const Text('Clear Filters'),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.textSecondary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
            ),
          ),
        ],
        if (!isMobile) ...[const SizedBox(height: 16), _buildCreateButton()],
      ],
    );
  }

  Widget _buildFilterDropdown({
    required String label,
    required String value,
    required List<String> options,
    required Function(String?) onChanged,
    bool isCompact = false,
  }) {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
        ),
        filled: true,
        fillColor: const Color(0xFFF8FAFB),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: isCompact ? 12 : 16,
        ),
        labelStyle: TextStyle(
          color: AppTheme.textSecondary,
          fontWeight: FontWeight.w500,
        ),
      ),
      value: value,
      isExpanded: true,
      icon: Icon(
        Icons.keyboard_arrow_down_rounded,
        color: AppTheme.textSecondary,
      ),
      style: TextStyle(
        fontSize: 14,
        color: AppTheme.textPrimary,
        fontWeight: FontWeight.w500,
      ),
      dropdownColor: Colors.white,
      items:
          options.map((option) {
            String displayText = option;
            if (option == 'Financial Planning and Budgeting Officer' &&
                isCompact) {
              displayText = 'Financial Officer';
            }

            return DropdownMenuItem(
              value: option,
              child: Text(
                displayText,
                style: TextStyle(fontSize: 14, color: AppTheme.textPrimary),
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildCreateButton() {
    return ElevatedButton.icon(
      onPressed: _showCreateAccountDialog,
      icon: const Icon(Icons.add_rounded, size: 20),
      label: Text(isDesktop ? 'Create Account' : 'Create'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(
          horizontal: isDesktop ? 24 : 20,
          vertical: 16,
        ),
        elevation: 0,
        shadowColor: AppTheme.primaryColor.withOpacity(0.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return FloatingActionButton.extended(
      onPressed: _showCreateAccountDialog,
      backgroundColor: AppTheme.primaryColor,
      foregroundColor: Colors.white,
      elevation: 4,
      icon: const Icon(Icons.add_rounded),
      label: const Text(
        'Create',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }

  Widget _buildSkeletonLoading() {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              _buildSkeletonBox(height: 24, width: 200),
              const SizedBox(height: 20),
              _buildSkeletonBox(height: 52),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: _buildSkeletonBox(height: 56)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildSkeletonBox(height: 56)),
                  if (isDesktop) ...[
                    const SizedBox(width: 16),
                    _buildSkeletonBox(height: 56, width: 160),
                  ],
                ],
              ),
            ],
          ),
        ),
        Expanded(child: _buildAccountsSkeletonGrid()),
      ],
    );
  }

  Widget _buildSkeletonBox({double? height, double? width}) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  Widget _buildAccountsSkeletonGrid() {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _getGridCrossAxisCount(),
        mainAxisExtent: _getCardHeight(),
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: 6,
      itemBuilder:
          (_, __) => Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSkeletonBox(height: 16, width: 120),
                          const SizedBox(height: 8),
                          _buildSkeletonBox(height: 14, width: 160),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildSkeletonBox(height: 24, width: 60),
                    const SizedBox(width: 8),
                    _buildSkeletonBox(height: 24, width: 100),
                  ],
                ),
                const Spacer(),
                _buildSkeletonBox(height: 36),
              ],
            ),
          ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(60),
              ),
              child: Icon(
                Icons.people_outline_rounded,
                size: 60,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _hasActiveFilters() ? 'No matching accounts' : 'No accounts yet',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              _hasActiveFilters()
                  ? 'Try adjusting your search or filter criteria'
                  : 'Create your first team member account to get started',
              style: TextStyle(
                fontSize: 16,
                color: AppTheme.textSecondary,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            _hasActiveFilters()
                ? OutlinedButton.icon(
                  onPressed: _resetFilters,
                  icon: const Icon(Icons.filter_alt_off_rounded),
                  label: const Text('Clear Filters'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    side: BorderSide(color: AppTheme.primaryColor),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                )
                : ElevatedButton.icon(
                  onPressed: _showCreateAccountDialog,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Create First Account'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountsList() {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _getGridCrossAxisCount(),
        mainAxisExtent: _getCardHeight(),
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _filteredAccounts.length,
      itemBuilder: (context, index) {
        final account = _filteredAccounts[index];
        return TweenAnimationBuilder<double>(
          duration: Duration(milliseconds: 300 + (index * 50)),
          tween: Tween(begin: 0.0, end: 1.0),
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(0, 20 * (1 - value)),
              child: Opacity(opacity: value, child: _buildAccountCard(account)),
            );
          },
        );
      },
    );
  }

  int _getGridCrossAxisCount() {
    if (isDesktop) return 3;
    if (isTablet) return 2;
    return 1;
  }

  double _getCardHeight() {
    if (isMobile) return 280;
    return 240;
  }

  Widget _buildAccountCard(Map<String, dynamic> account) {
    final isAdmin = account['role'] == 'Administrator';
    final isActive = account['status'] == 'Active';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color:
              isActive
                  ? Colors.green.withOpacity(0.2)
                  : Colors.orange.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () => _viewAccountDetails(account),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCardHeader(account),
                const SizedBox(height: 16),
                _buildCardBadges(account),
                if (account['contact_number']?.isNotEmpty ?? false) ...[
                  const SizedBox(height: 12),
                  _buildContactInfo(account),
                ],
                const Spacer(),
                Divider(color: Colors.grey[100], thickness: 1),
                const SizedBox(height: 12),
                _buildCardActions(account, isAdmin),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardHeader(Map<String, dynamic> account) {
    return Row(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.primaryColor,
                AppTheme.primaryColor.withOpacity(0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Text(
              '${account['f_name']?[0] ?? ''}${account['l_name']?[0] ?? ''}'
                  .toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
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
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
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
                  height: 1.2,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCardBadges(Map<String, dynamic> account) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        EnhancedStatusBadge(status: account['status'] ?? 'Unknown'),
        EnhancedRoleBadge(
          role: account['role'] ?? 'Unknown',
          compact: !isDesktop,
        ),
      ],
    );
  }

  Widget _buildContactInfo(Map<String, dynamic> account) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.phone_rounded, size: 16, color: AppTheme.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              account['contact_number'] ?? '',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardActions(Map<String, dynamic> account, bool isAdmin) {
    final isActive = account['status'] == 'Active';

    if (isAdmin) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => _viewAccountDetails(account),
          icon: const Icon(Icons.visibility_outlined, size: 16),
          label: const Text('View Details'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.primaryColor,
            side: BorderSide(color: AppTheme.primaryColor.withOpacity(0.5)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      );
    }

    if (isMobile) {
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _viewAccountDetails(account),
              icon: const Icon(Icons.visibility_outlined, size: 16),
              label: const Text('View Details'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryColor,
                side: BorderSide(color: AppTheme.primaryColor.withOpacity(0.5)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  icon: Icons.edit_outlined,
                  label: 'Edit',
                  color: Colors.blue[700]!,
                  backgroundColor: Colors.blue[50]!,
                  onPressed: () => _showEditAccountDialog(account),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildActionButton(
                  icon:
                      isActive
                          ? Icons.block_outlined
                          : Icons.check_circle_outlined,
                  label: isActive ? 'Disable' : 'Enable',
                  color: isActive ? Colors.orange[700]! : Colors.green[700]!,
                  backgroundColor:
                      isActive ? Colors.orange[50]! : Colors.green[50]!,
                  onPressed: () => _toggleAccountStatus(account),
                ),
              ),
              const SizedBox(width: 8),
              _buildIconActionButton(
                icon: Icons.delete_outlined,
                color: Colors.red[700]!,
                backgroundColor: Colors.red[50]!,
                onPressed: () => _deleteAccount(account),
              ),
            ],
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _viewAccountDetails(account),
            icon: const Icon(Icons.visibility_outlined, size: 16),
            label: const Text('Details'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primaryColor,
              side: BorderSide(color: AppTheme.primaryColor.withOpacity(0.5)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _buildIconActionButton(
          icon: Icons.edit_outlined,
          color: Colors.blue[700]!,
          backgroundColor: Colors.blue[50]!,
          onPressed: () => _showEditAccountDialog(account),
        ),
        const SizedBox(width: 8),
        _buildIconActionButton(
          icon: isActive ? Icons.block_outlined : Icons.check_circle_outlined,
          color: isActive ? Colors.orange[700]! : Colors.green[700]!,
          backgroundColor: isActive ? Colors.orange[50]! : Colors.green[50]!,
          onPressed: () => _toggleAccountStatus(account),
        ),
        const SizedBox(width: 8),
        _buildIconActionButton(
          icon: Icons.delete_outlined,
          color: Colors.red[700]!,
          backgroundColor: Colors.red[50]!,
          onPressed: () => _deleteAccount(account),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required Color backgroundColor,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: color,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildIconActionButton({
    required IconData icon,
    required Color color,
    required Color backgroundColor,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      color: color,
      style: IconButton.styleFrom(
        backgroundColor: backgroundColor,
        padding: const EdgeInsets.all(8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  void dispose() {
    _authCheckTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }
}

// Enhanced Status Badge
class EnhancedStatusBadge extends StatelessWidget {
  final String status;

  const EnhancedStatusBadge({Key? key, required this.status}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isActive = status == 'Active';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors:
              isActive
                  ? [Colors.green.shade50, Colors.green.shade100]
                  : [Colors.orange.shade50, Colors.orange.shade100],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color:
              isActive
                  ? Colors.green.withOpacity(0.3)
                  : Colors.orange.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: isActive ? Colors.green[600] : Colors.orange[600],
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            status,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isActive ? Colors.green[700] : Colors.orange[700],
            ),
          ),
        ],
      ),
    );
  }
}

// Enhanced Role Badge
class EnhancedRoleBadge extends StatelessWidget {
  final String role;
  final bool compact;

  const EnhancedRoleBadge({Key? key, required this.role, this.compact = false})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    final config = _getRoleConfig(role);
    String displayRole =
        compact && role == 'Financial Planning and Budgeting Officer'
            ? 'Financial Officer'
            : role;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            config.color.withOpacity(0.1),
            config.color.withOpacity(0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: config.color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(config.icon, size: 12, color: config.color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              displayRole,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: config.color,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  _RoleConfig _getRoleConfig(String role) {
    switch (role) {
      case 'Administrator':
        return _RoleConfig(
          Colors.purple[700]!,
          Icons.admin_panel_settings_rounded,
        );
      case 'Budget Manager':
        return _RoleConfig(
          Colors.blue[700]!,
          Icons.account_balance_wallet_rounded,
        );
      case 'Financial Planning and Budgeting Officer':
        return _RoleConfig(Colors.teal[700]!, Icons.trending_up_rounded);
      case 'Authorized Spender':
        return _RoleConfig(Colors.indigo[700]!, Icons.shopping_cart_rounded);
      default:
        return _RoleConfig(Colors.grey[700]!, Icons.person_rounded);
    }
  }
}

class _RoleConfig {
  final Color color;
  final IconData icon;

  _RoleConfig(this.color, this.icon);
}
