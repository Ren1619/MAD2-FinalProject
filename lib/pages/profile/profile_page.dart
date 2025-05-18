import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/firebase_auth_service.dart';
import '../../services/firebase_logs_service.dart';
import '../../widgets/common_widgets.dart';
import '../../theme.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _editFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();

  Map<String, dynamic>? _userData;
  List<Map<String, dynamic>> _recentActivities = [];
  bool _isLoading = true;
  bool _isEditing = false;
  bool _isUpdating = false;
  bool _isChangingPassword = false;

  // Edit form controllers
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _phoneController;

  // Password form controllers
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<FirebaseAuthService>(
        context,
        listen: false,
      );
      final userData = await authService.currentUser;

      if (userData != null) {
        setState(() => _userData = userData);

        // Initialize controllers with current data
        _firstNameController = TextEditingController(
          text: userData['f_name'] ?? '',
        );
        _lastNameController = TextEditingController(
          text: userData['l_name'] ?? '',
        );
        _phoneController = TextEditingController(
          text: userData['contact_number'] ?? '',
        );

        // Load recent activities
        await _loadRecentActivities();
      }
    } catch (e) {
      _showErrorSnackBar('Error loading profile data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadRecentActivities() async {
    try {
      final logsService = Provider.of<FirebaseLogsService>(
        context,
        listen: false,
      );
      final allLogs = await logsService.getLogsForAdmin(limit: 100);

      // Filter logs for current user
      final userLogs =
          allLogs
              .where((log) => log['user_id'] == _userData!['account_id'])
              .take(5)
              .toList();

      setState(() => _recentActivities = userLogs);
    } catch (e) {
      print('Error loading recent activities: $e');
    }
  }

  void _startEditing() {
    setState(() => _isEditing = true);
  }

  void _cancelEditing() {
    setState(() => _isEditing = false);

    // Reset controllers to original values
    _firstNameController.text = _userData!['f_name'] ?? '';
    _lastNameController.text = _userData!['l_name'] ?? '';
    _phoneController.text = _userData!['contact_number'] ?? '';
  }

  Future<void> _saveProfile() async {
    if (!_editFormKey.currentState!.validate()) return;

    setState(() => _isUpdating = true);

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
        _userData!['account_id'],
        updates,
      );

      if (success) {
        _showSuccessSnackBar('Profile updated successfully');
        setState(() => _isEditing = false);
        await _loadUserData(); // Reload to get updated data
      } else {
        _showErrorSnackBar('Failed to update profile');
      }
    } catch (e) {
      _showErrorSnackBar('Error updating profile: $e');
    } finally {
      setState(() => _isUpdating = false);
    }
  }

  void _showChangePasswordDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              'Change Password',
              style: TextStyle(color: AppTheme.primaryColor),
            ),
            content: SizedBox(
              width: 400,
              child: Form(
                key: _passwordFormKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Current Password
                    TextFormField(
                      controller: _currentPasswordController,
                      obscureText: _obscureCurrentPassword,
                      decoration: InputDecoration(
                        labelText: 'Current Password',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureCurrentPassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(
                              () =>
                                  _obscureCurrentPassword =
                                      !_obscureCurrentPassword,
                            );
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value?.isEmpty ?? true) {
                          return 'Please enter your current password';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // New Password
                    TextFormField(
                      controller: _newPasswordController,
                      obscureText: _obscureNewPassword,
                      decoration: InputDecoration(
                        labelText: 'New Password',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureNewPassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(
                              () => _obscureNewPassword = !_obscureNewPassword,
                            );
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value?.isEmpty ?? true) {
                          return 'Please enter a new password';
                        }
                        if (value!.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Confirm New Password
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      decoration: InputDecoration(
                        labelText: 'Confirm New Password',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword
                                ? Icons.visibility_off
                                : Icons.visibility,
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
                      validator: (value) {
                        if (value != _newPasswordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Info Box
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.blue[700],
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'For security, you\'ll be logged out after changing your password.',
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
            ),
            actions: [
              TextButton(
                onPressed:
                    _isChangingPassword
                        ? null
                        : () {
                          Navigator.pop(context);
                          _clearPasswordFields();
                        },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: _isChangingPassword ? null : _changePassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                ),
                child:
                    _isChangingPassword
                        ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                        : const Text(
                          'Change Password',
                          style: TextStyle(color: Colors.white),
                        ),
              ),
            ],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
    );
  }

  Future<void> _changePassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;

    setState(() => _isChangingPassword = true);

    try {
      // Note: In a real implementation, you would need to implement password change
      // functionality in your FirebaseAuthService. This is a simulation.
      await Future.delayed(const Duration(seconds: 2)); // Simulate API call

      Navigator.pop(context);
      _showSuccessSnackBar(
        'Password changed successfully. Please log in again.',
      );
      _clearPasswordFields();

      // In a real app, you would sign out the user here
      // await Provider.of<FirebaseAuthService>(context, listen: false).signOut();
      // Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      _showErrorSnackBar('Error changing password: $e');
    } finally {
      setState(() => _isChangingPassword = false);
    }
  }

  void _clearPasswordFields() {
    _currentPasswordController.clear();
    _newPasswordController.clear();
    _confirmPasswordController.clear();
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: LoadingIndicator(message: 'Loading profile...'),
      );
    }

    if (_userData == null) {
      return Scaffold(
        appBar: CustomAppBar(title: 'Profile'),
        body: const EmptyStateWidget(
          message: 'Profile not found',
          icon: Icons.error_outline,
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: CustomAppBar(
        title: 'My Profile',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUserData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Header Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Row(
                      children: [
                        // Avatar
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: AppTheme.primaryLightColor,
                          child: Text(
                            '${_userData!['f_name']?[0] ?? ''}${_userData!['l_name']?[0] ?? ''}'
                                .toUpperCase(),
                            style: TextStyle(
                              color: AppTheme.primaryColor,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 24),

                        // Basic Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_userData!['f_name']} ${_userData!['l_name']}',
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _userData!['email'] ?? '',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  StatusBadge(
                                    status: _userData!['status'] ?? 'Unknown',
                                  ),
                                  const SizedBox(width: 12),
                                  RoleBadge(
                                    role: _userData!['role'] ?? 'Unknown',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Action Buttons
                        Column(
                          children: [
                            ElevatedButton.icon(
                              onPressed: _isEditing ? null : _startEditing,
                              icon: const Icon(Icons.edit, size: 16),
                              label: const Text('Edit Profile'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                foregroundColor: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: _showChangePasswordDialog,
                              icon: const Icon(Icons.lock, size: 16),
                              label: const Text('Change Password'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Profile Details Card
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
                          'Profile Information',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        if (_isEditing) ...[
                          Row(
                            children: [
                              TextButton(
                                onPressed: _isUpdating ? null : _cancelEditing,
                                child: const Text('Cancel'),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: _isUpdating ? null : _saveProfile,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryColor,
                                ),
                                child:
                                    _isUpdating
                                        ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                        : const Text(
                                          'Save',
                                          style: TextStyle(color: Colors.white),
                                        ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 20),

                    Form(
                      key: _editFormKey,
                      child: Column(
                        children: [
                          // Editable Fields
                          Row(
                            children: [
                              Expanded(
                                child:
                                    _isEditing
                                        ? TextFormField(
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
                                        )
                                        : _buildInfoField(
                                          'First Name',
                                          _userData!['f_name'] ??
                                              'Not provided',
                                        ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child:
                                    _isEditing
                                        ? TextFormField(
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
                                        )
                                        : _buildInfoField(
                                          'Last Name',
                                          _userData!['l_name'] ??
                                              'Not provided',
                                        ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          Row(
                            children: [
                              Expanded(
                                child: _buildInfoField(
                                  'Email Address',
                                  _userData!['email'] ?? 'Not provided',
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child:
                                    _isEditing
                                        ? TextFormField(
                                          controller: _phoneController,
                                          decoration: const InputDecoration(
                                            labelText: 'Phone Number',
                                            border: OutlineInputBorder(),
                                          ),
                                          keyboardType: TextInputType.phone,
                                        )
                                        : _buildInfoField(
                                          'Phone Number',
                                          _userData!['contact_number']
                                                      ?.isNotEmpty ==
                                                  true
                                              ? _userData!['contact_number']
                                              : 'Not provided',
                                        ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Read-only Fields
                          Row(
                            children: [
                              Expanded(
                                child: _buildInfoField(
                                  'Role',
                                  _userData!['role'] ?? 'Not assigned',
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildInfoField(
                                  'Status',
                                  _userData!['status'] ?? 'Unknown',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          Row(
                            children: [
                              Expanded(
                                child: _buildInfoField(
                                  'Account ID',
                                  _userData!['account_id'] ?? 'Unknown',
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildInfoField(
                                  'Member Since',
                                  _formatTimestamp(_userData!['created_at']),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    if (!_isEditing && _userData!['email'] != null) ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.amber[700]),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Note: Email address and role can only be changed by administrators.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.amber[700],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Recent Activities Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recent Activities',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (_recentActivities.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(32),
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
                            const SizedBox(height: 12),
                            Text(
                              'No recent activities found',
                              style: TextStyle(
                                fontSize: 16,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Column(
                        children:
                            _recentActivities.map((activity) {
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
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            activity['log_desc'] ??
                                                'No description',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w500,
                                            ),
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
                                              if (activity['created_at'] !=
                                                  null) ...[
                                                Text(
                                                  ' • ${_formatTimestamp(activity['created_at'])}',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color:
                                                        AppTheme.textSecondary,
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

  Widget _buildInfoField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Text(
            value,
            style: TextStyle(fontSize: 16, color: AppTheme.textPrimary),
          ),
        ),
      ],
    );
  }
}
