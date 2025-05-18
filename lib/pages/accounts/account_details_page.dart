import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/firebase_auth_service.dart';
import '../../services/firebase_logs_service.dart';
import '../../widgets/common_widgets.dart';
import '../../theme.dart';

class AccountDetailsPage extends StatefulWidget {
  final Map<String, dynamic> account;

  const AccountDetailsPage({super.key, required this.account});

  @override
  State<AccountDetailsPage> createState() => _AccountDetailsPageState();
}

class _AccountDetailsPageState extends State<AccountDetailsPage> {
  Map<String, dynamic>? _accountData;
  List<Map<String, dynamic>> _recentActivities = [];
  bool _isLoading = true;
  bool _isUpdatingStatus = false;

  @override
  void initState() {
    super.initState();
    _loadAccountDetails();
    _loadAccountActivities();
  }

  Future<void> _loadAccountDetails() async {
    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<FirebaseAuthService>(
        context,
        listen: false,
      );
      final userData = await authService.currentUser;

      if (userData != null) {
        final companyId = userData['company_id'];
        final accounts = await authService.getAccountsByCompany(companyId);

        final account = accounts.firstWhere(
          (acc) => acc['account_id'] == widget.account['account_id'],
          orElse: () => widget.account,
        );

        setState(() {
          _accountData = account;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Error loading account details: $e');
    }
  }

  Future<void> _loadAccountActivities() async {
    try {
      final logsService = Provider.of<FirebaseLogsService>(
        context,
        listen: false,
      );

      // Get all logs for the company
      final allLogs = await logsService.getLogsForAdmin(limit: 100);

      // Filter logs for this specific user
      final userLogs =
          allLogs
              .where((log) => log['user_id'] == widget.account['account_id'])
              .take(10)
              .toList();

      setState(() {
        _recentActivities = userLogs;
      });
    } catch (e) {
      print('Error loading account activities: $e');
    }
  }

  Future<void> _updateAccountStatus(String newStatus) async {
    setState(() => _isUpdatingStatus = true);

    try {
      final authService = Provider.of<FirebaseAuthService>(
        context,
        listen: false,
      );
      final success = await authService.updateUserStatus(
        widget.account['account_id'],
        newStatus,
      );

      if (success) {
        _showSuccessSnackBar('Account status updated successfully');
        await _loadAccountDetails();
      } else {
        _showErrorSnackBar('Failed to update account status');
      }
    } catch (e) {
      _showErrorSnackBar('Error updating account status: $e');
    } finally {
      setState(() => _isUpdatingStatus = false);
    }
  }

  void _showEditDialog() {
    showDialog(
      context: context,
      builder:
          (context) => _EditAccountDetailsDialog(
            account: _accountData!,
            onUpdated: () {
              Navigator.pop(context);
              _loadAccountDetails();
            },
          ),
    );
  }

  void _showDeleteConfirmation() {
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
                const Text('Are you sure you want to delete this account?'),
                const SizedBox(height: 8),
                Text(
                  '${_accountData!['f_name']} ${_accountData!['l_name']} (${_accountData!['email']})',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'This action cannot be undone and will permanently remove all associated data.',
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
                      _accountData!['account_id'],
                    );

                    if (success) {
                      _showSuccessSnackBar('Account deleted successfully');
                      Navigator.pop(context); // Return to accounts list
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
    if (_isLoading) {
      return const Scaffold(
        body: LoadingIndicator(message: 'Loading account details...'),
      );
    }

    if (_accountData == null) {
      return Scaffold(
        appBar: CustomAppBar(title: 'Account Details'),
        body: const EmptyStateWidget(
          message: 'Account not found',
          icon: Icons.error_outline,
        ),
      );
    }

    final isAdmin = _accountData!['role'] == 'Administrator';
    final isActive = _accountData!['status'] == 'Active';

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: CustomAppBar(
        title: 'Account Details',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadAccountDetails();
              _loadAccountActivities();
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Account Information Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: AppTheme.primaryLightColor,
                          child: Text(
                            '${_accountData!['f_name']?[0] ?? ''}${_accountData!['l_name']?[0] ?? ''}'
                                .toUpperCase(),
                            style: TextStyle(
                              color: AppTheme.primaryColor,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_accountData!['f_name']} ${_accountData!['l_name']}',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _accountData!['email'] ?? '',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  StatusBadge(
                                    status:
                                        _accountData!['status'] ?? 'Unknown',
                                  ),
                                  const SizedBox(width: 12),
                                  RoleBadge(
                                    role: _accountData!['role'] ?? 'Unknown',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Account Details Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Account Information',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        if (!isAdmin)
                          ElevatedButton.icon(
                            onPressed: _showEditDialog,
                            icon: const Icon(Icons.edit, size: 16),
                            label: const Text('Edit'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    _buildDetailRow(
                      'Account ID',
                      _accountData!['account_id'] ?? 'N/A',
                    ),
                    _buildDetailRow(
                      'Email Address',
                      _accountData!['email'] ?? 'N/A',
                    ),
                    _buildDetailRow(
                      'Phone Number',
                      _accountData!['contact_number']?.isNotEmpty == true
                          ? _accountData!['contact_number']
                          : 'Not provided',
                    ),
                    _buildDetailRow('Role', _accountData!['role'] ?? 'N/A'),
                    _buildDetailRow('Status', _accountData!['status'] ?? 'N/A'),
                    _buildDetailRow(
                      'Account Created',
                      _formatTimestamp(_accountData!['created_at']),
                    ),
                    if (_accountData!['updated_at'] != null)
                      _buildDetailRow(
                        'Last Updated',
                        _formatTimestamp(_accountData!['updated_at']),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Account Actions Section
            if (!isAdmin) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Account Actions',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed:
                                  _isUpdatingStatus
                                      ? null
                                      : () => _updateAccountStatus(
                                        isActive ? 'Inactive' : 'Active',
                                      ),
                              icon:
                                  _isUpdatingStatus
                                      ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                      : Icon(
                                        isActive
                                            ? Icons.block
                                            : Icons.check_circle,
                                      ),
                              label: Text(
                                isActive ? 'Disable Account' : 'Enable Account',
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    isActive ? Colors.orange : Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _showDeleteConfirmation,
                              icon: const Icon(Icons.delete),
                              label: const Text('Delete Account'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: const BorderSide(color: Colors.red),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],

            // Recent Activities Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recent Activities',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (_recentActivities.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(24),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.history,
                              size: 48,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'No recent activities found',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Column(
                        children:
                            _recentActivities.map((activity) {
                              return _buildActivityItem(activity);
                            }).toList(),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
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

  Widget _buildActivityItem(Map<String, dynamic> activity) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryLightColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getActivityIcon(activity['type']),
              color: AppTheme.primaryColor,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity['log_desc'] ?? 'No description',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      activity['type'] ?? 'Unknown',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    if (activity['created_at'] != null) ...[
                      Text(
                        ' • ${_formatTimestamp(activity['created_at'])}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getActivityIcon(String? type) {
    switch (type) {
      case 'Authentication':
        return Icons.login;
      case 'Account Management':
        return Icons.person;
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
}

// Edit Account Details Dialog
class _EditAccountDetailsDialog extends StatefulWidget {
  final Map<String, dynamic> account;
  final VoidCallback onUpdated;

  const _EditAccountDetailsDialog({
    required this.account,
    required this.onUpdated,
  });

  @override
  State<_EditAccountDetailsDialog> createState() =>
      _EditAccountDetailsDialogState();
}

class _EditAccountDetailsDialogState extends State<_EditAccountDetailsDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
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
    _phoneController = TextEditingController(
      text: widget.account['contact_number'] ?? '',
    );
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
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
        widget.onUpdated();
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
        'Edit Account Details',
        style: TextStyle(color: AppTheme.primaryColor),
      ),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
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
              const SizedBox(height: 16),
              TextFormField(
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
                        'Email: ${widget.account['email']}\nRole: ${widget.account['role']}\n\nEmail and role cannot be changed.',
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
                  : const Text('Update', style: TextStyle(color: Colors.white)),
        ),
      ],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }
}
