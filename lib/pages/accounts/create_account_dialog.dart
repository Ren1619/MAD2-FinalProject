import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/firebase_auth_service.dart';
import '../../services/firebase_logs_service.dart';
import '../../widgets/common_widgets.dart';
import '../../theme.dart';

class CreateAccountDialog extends StatefulWidget {
  final VoidCallback onAccountCreated;

  const CreateAccountDialog({Key? key, required this.onAccountCreated})
    : super(key: key);

  @override
  State<CreateAccountDialog> createState() => _CreateAccountDialogState();
}

class _CreateAccountDialogState extends State<CreateAccountDialog>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _adminPasswordController = TextEditingController();

  String _selectedRole = 'Budget Manager';
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _obscureAdminPassword = true;
  String? _adminEmail;
  double _passwordStrength = 0.0;
  String _passwordStrengthText = 'Weak';
  Color _passwordStrengthColor = Colors.red;
  bool _passwordsMatch = false;

  late AnimationController _animationController;
  late Animation<double> _animation;

  final List<String> _roleDescriptions = [
    'Can manage all budget-related operations',
    'Can oversee financial planning and budgeting',
    'Can make authorized purchases',
  ];

  // Focus nodes for keyboard navigation
  final _firstNameFocus = FocusNode();
  final _lastNameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _roleFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmPasswordFocus = FocusNode();
  final _adminPasswordFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadAdminEmail();

    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    _animationController.forward();

    // Add listeners for password strength and matching
    _passwordController.addListener(_updatePasswordStrength);
    _confirmPasswordController.addListener(_checkPasswordsMatch);
  }

  void _updatePasswordStrength() {
    final password = _passwordController.text;
    double strength = 0.0;
    String text = 'Weak';
    Color color = Colors.red;

    if (password.length >= 8) strength += 0.2;
    if (password.contains(RegExp(r'[A-Z]'))) strength += 0.2;
    if (password.contains(RegExp(r'[a-z]'))) strength += 0.2;
    if (password.contains(RegExp(r'[0-9]'))) strength += 0.2;
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) strength += 0.2;

    if (strength <= 0.4) {
      text = 'Weak';
      color = Colors.red;
    } else if (strength <= 0.7) {
      text = 'Medium';
      color = Colors.orange;
    } else {
      text = 'Strong';
      color = Colors.green;
    }

    setState(() {
      _passwordStrength = strength;
      _passwordStrengthText = text;
      _passwordStrengthColor = color;
    });
  }

  void _checkPasswordsMatch() {
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    setState(() {
      _passwordsMatch = password.isNotEmpty && password == confirmPassword;
    });
  }

  Future<void> _loadAdminEmail() async {
    final authService = Provider.of<FirebaseAuthService>(
      context,
      listen: false,
    );
    final userData = await authService.currentUser;
    if (userData != null) {
      setState(() {
        _adminEmail = userData['email'];
      });
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _adminPasswordController.dispose();
    _animationController.dispose();

    // Dispose focus nodes
    _firstNameFocus.dispose();
    _lastNameFocus.dispose();
    _emailFocus.dispose();
    _phoneFocus.dispose();
    _roleFocus.dispose();
    _passwordFocus.dispose();
    _confirmPasswordFocus.dispose();
    _adminPasswordFocus.dispose();

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

      // Get current admin user data
      final currentUserData = await authService.currentUser;
      if (currentUserData == null) {
        throw 'Unable to get current user data';
      }

      final companyId = currentUserData['company_id'];
      final adminEmail = currentUserData['email'];

      // Use the method with auto re-authentication
      final success = await authService.createUserAccountWithAutoReauth(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        role: _selectedRole,
        phone: _phoneController.text.trim(),
        companyId: companyId,
        adminEmail: adminEmail,
        adminPassword: _adminPasswordController.text,
      );

      if (success) {
        // Close the create dialog and refresh the accounts page
        if (mounted) {
          Navigator.pop(context);
          widget.onAccountCreated();

          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Account created successfully for ${_emailController.text}',
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green[700],
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              margin: const EdgeInsets.all(10),
            ),
          );
        }
      } else {
        // Account creation failed
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: const [
                  Icon(Icons.error_outline, color: Colors.white),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text('Failed to create account. Please try again.'),
                  ),
                ],
              ),
              backgroundColor: Colors.red[700],
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Error creating account: $e';

        // Handle specific errors
        if (e.toString().contains('wrong-password') ||
            e.toString().contains('invalid-email')) {
          errorMessage =
              'Invalid admin password. Please check your password and try again.';
        } else if (e.toString().contains('email-already-in-use')) {
          errorMessage = 'An account with this email already exists.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(child: Text(errorMessage)),
              ],
            ),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getRoleDescription(String role) {
    switch (role) {
      case 'Budget Manager':
        return _roleDescriptions[0];
      case 'Financial Planning and Budgeting Officer':
        return _roleDescriptions[1];
      case 'Authorized Spender':
        return _roleDescriptions[2];
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get the screen size to determine layout
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;

    // Determine if we're on mobile, tablet, or desktop
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 900;
    final isDesktop = screenWidth >= 900;

    // Calculate dialog width based on screen size
    double dialogWidth =
        isDesktop
            ? 600
            : isTablet
            ? screenWidth * 0.8
            : screenWidth * 0.95;

    // Calculate max height for the dialog
    final maxHeight = MediaQuery.of(context).size.height * 0.85;

    // On mobile, use a BottomSheet style for better UX
    if (isMobile) {
      return _buildMobileLayout(maxHeight);
    }

    // For tablet and desktop use a standard dialog with responsive sizing
    return _buildDesktopLayout(dialogWidth, maxHeight, isDesktop);
  }

  Widget _buildMobileLayout(double maxHeight) {
    return FadeTransition(
      opacity: _animation,
      child: Dialog(
        insetPadding: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(maxHeight: maxHeight),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Mobile header with drag handle
              _buildMobileHeader(),

              // Form content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // User Information Section
                          _buildSectionTitle('User Information'),
                          const SizedBox(height: 16),
                          _buildMobileNameFields(),
                          const SizedBox(height: 16),
                          _buildEmailField(mobile: true),
                          const SizedBox(height: 16),
                          _buildPhoneField(mobile: true),
                          const SizedBox(height: 16),
                          _buildRoleDropdown(mobile: true),
                          const SizedBox(height: 16),

                          // Password Section
                          _buildSectionTitle('Security'),
                          const SizedBox(height: 16),
                          _buildPasswordField(mobile: true),
                          const SizedBox(height: 4),
                          _buildPasswordStrengthIndicator(),
                          const SizedBox(height: 16),
                          _buildConfirmPasswordField(mobile: true),
                          const SizedBox(height: 24),

                          // Admin Verification Section
                          _buildAdminVerificationSection(mobile: true),

                          // Add extra space at bottom for mobile
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Mobile actions
              _buildMobileActions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(
    double dialogWidth,
    double maxHeight,
    bool isDesktop,
  ) {
    return FadeTransition(
      opacity: _animation,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 8,
        backgroundColor: Colors.transparent,
        child: Container(
          width: dialogWidth,
          constraints: BoxConstraints(maxHeight: maxHeight),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  _buildHeader(),

                  // Form content
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                      child: Form(
                        key: _formKey,
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // User Information Section
                              _buildSectionTitle('User Information'),
                              const SizedBox(height: 16),

                              // For desktop, use a two-column layout
                              if (isDesktop)
                                _buildDesktopFormFields()
                              else
                                _buildTabletFormFields(),

                              // Admin Verification Section
                              _buildAdminVerificationSection(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Actions
                  _buildActions(),
                ],
              ),

              // Close button
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Close',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopFormFields() {
    return Column(
      children: [
        // Row 1: Name fields side by side
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildInputField(
                controller: _firstNameController,
                label: 'First Name',
                icon: Icons.badge_outlined,
                focusNode: _firstNameFocus,
                nextFocus: _lastNameFocus,
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
              child: _buildInputField(
                controller: _lastNameController,
                label: 'Last Name',
                icon: Icons.badge_outlined,
                focusNode: _lastNameFocus,
                nextFocus: _emailFocus,
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

        // Row 2: Email and Phone side by side
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildEmailField()),
            const SizedBox(width: 16),
            Expanded(child: _buildPhoneField()),
          ],
        ),
        const SizedBox(height: 16),

        // Row 3: Role dropdown
        _buildRoleDropdown(),
        const SizedBox(height: 16),

        // Row 4: Password section title
        _buildSectionTitle('Security'),
        const SizedBox(height: 16),

        // Row 5: Password fields side by side
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPasswordField(),
                  const SizedBox(height: 4),
                  _buildPasswordStrengthIndicator(),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(child: _buildConfirmPasswordField()),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildTabletFormFields() {
    return Column(
      children: [
        // Row 1: Name fields side by side
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildInputField(
                controller: _firstNameController,
                label: 'First Name',
                icon: Icons.badge_outlined,
                focusNode: _firstNameFocus,
                nextFocus: _lastNameFocus,
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
              child: _buildInputField(
                controller: _lastNameController,
                label: 'Last Name',
                icon: Icons.badge_outlined,
                focusNode: _lastNameFocus,
                nextFocus: _emailFocus,
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

        // Single column for other fields
        _buildEmailField(),
        const SizedBox(height: 16),
        _buildPhoneField(),
        const SizedBox(height: 16),
        _buildRoleDropdown(),
        const SizedBox(height: 16),

        _buildSectionTitle('Security'),
        const SizedBox(height: 16),
        _buildPasswordField(),
        const SizedBox(height: 4),
        _buildPasswordStrengthIndicator(),
        const SizedBox(height: 16),
        _buildConfirmPasswordField(),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildMobileHeader() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Drag handle for bottom sheet feel
        Center(
          child: Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.person_add_rounded,
                  color: AppTheme.primaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Create New Account',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
                tooltip: 'Close',
              ),
            ],
          ),
        ),
        Divider(color: Colors.grey[200]),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.person_add_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Text(
            'Create New Account',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Divider(color: Colors.grey[300])),
        ],
      ),
    );
  }

  Widget _buildMobileNameFields() {
    return Column(
      children: [
        _buildInputField(
          controller: _firstNameController,
          label: 'First Name',
          icon: Icons.badge_outlined,
          focusNode: _firstNameFocus,
          nextFocus: _lastNameFocus,
          validator: (value) {
            if (value?.trim().isEmpty ?? true) {
              return 'First name is required';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        _buildInputField(
          controller: _lastNameController,
          label: 'Last Name',
          icon: Icons.badge_outlined,
          focusNode: _lastNameFocus,
          nextFocus: _emailFocus,
          validator: (value) {
            if (value?.trim().isEmpty ?? true) {
              return 'Last name is required';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildEmailField({bool mobile = false}) {
    return _buildInputField(
      controller: _emailController,
      label: 'Email Address',
      icon: Icons.email_outlined,
      keyboardType: TextInputType.emailAddress,
      focusNode: _emailFocus,
      nextFocus: _phoneFocus,
      validator: (value) {
        if (value?.trim().isEmpty ?? true) {
          return 'Email is required';
        }
        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value!)) {
          return 'Enter a valid email address';
        }
        return null;
      },
      mobile: mobile,
    );
  }

  Widget _buildPhoneField({bool mobile = false}) {
    return _buildInputField(
      controller: _phoneController,
      label: 'Phone Number (Optional)',
      icon: Icons.phone_outlined,
      keyboardType: TextInputType.phone,
      focusNode: _phoneFocus,
      nextFocus: _roleFocus,
      mobile: mobile,
    );
  }

  Widget _buildRoleDropdown({bool mobile = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[400]!),
            borderRadius: BorderRadius.circular(10),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'Role',
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: mobile ? 8 : 16,
                  vertical: mobile ? 8 : 12,
                ),
                icon: Container(
                  padding: EdgeInsets.only(left: mobile ? 8 : 16),
                  child: Icon(
                    Icons.work_outline,
                    color: Colors.grey[600],
                    size: mobile ? 18 : 20,
                  ),
                ),
              ),
              value: _selectedRole,
              isExpanded: true,
              icon: Padding(
                padding: EdgeInsets.only(right: mobile ? 8 : 16),
                child: Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
              ),
              focusNode: _roleFocus,
              onTap: () {
                FocusScope.of(context).requestFocus(FocusNode());
              },
              borderRadius: BorderRadius.circular(10),
              items:
                  FirebaseAuthService.getAvailableRoles().map((role) {
                    String displayRole = role;
                    if (role == 'Financial Planning and Budgeting Officer') {
                      displayRole = 'Financial Officer';
                    }

                    return DropdownMenuItem(
                      value: role,
                      child: Text(
                        displayRole,
                        style: TextStyle(
                          fontSize: mobile ? 13 : 14,
                          color: AppTheme.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    );
                  }).toList(),
              onChanged: (value) {
                setState(() => _selectedRole = value!);
                FocusScope.of(context).requestFocus(_passwordFocus);
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please select a role';
                }
                return null;
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8, left: 8),
          child: Text(
            _getRoleDescription(_selectedRole),
            style: TextStyle(
              fontSize: mobile ? 11 : 12,
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField({bool mobile = false}) {
    return _buildInputField(
      controller: _passwordController,
      label: 'Password',
      icon: Icons.lock_outline,
      obscureText: _obscurePassword,
      focusNode: _passwordFocus,
      nextFocus: _confirmPasswordFocus,
      suffixIcon: IconButton(
        icon: Icon(
          _obscurePassword ? Icons.visibility_off : Icons.visibility,
          size: mobile ? 18 : 20,
          color: Colors.grey[600],
        ),
        onPressed: () {
          setState(() => _obscurePassword = !_obscurePassword);
        },
      ),
      validator: (value) {
        if (value?.isEmpty ?? true) {
          return 'Password is required';
        }
        if (value!.length < 6) {
          return 'Password must be at least 6 characters';
        }
        return null;
      },
      mobile: mobile,
    );
  }

  Widget _buildPasswordStrengthIndicator() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: _passwordStrength,
            backgroundColor: Colors.grey[200],
            color: _passwordStrengthColor,
            minHeight: 5,
          ),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Password Strength: $_passwordStrengthText',
                style: TextStyle(
                  fontSize: 12,
                  color: _passwordStrengthColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                _passwordController.text.isEmpty
                    ? ''
                    : '${(_passwordStrength * 100).toInt()}%',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmPasswordField({bool mobile = false}) {
    return Stack(
      children: [
        _buildInputField(
          controller: _confirmPasswordController,
          label: 'Confirm Password',
          icon: Icons.lock_outlined,
          obscureText: _obscureConfirmPassword,
          focusNode: _confirmPasswordFocus,
          nextFocus: _adminPasswordFocus,
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_confirmPasswordController.text.isNotEmpty &&
                  _passwordController.text.isNotEmpty)
                Icon(
                  _passwordsMatch ? Icons.check_circle : Icons.error,
                  color: _passwordsMatch ? Colors.green : Colors.red,
                  size: mobile ? 18 : 20,
                ),
              IconButton(
                icon: Icon(
                  _obscureConfirmPassword
                      ? Icons.visibility_off
                      : Icons.visibility,
                  size: mobile ? 18 : 20,
                  color: Colors.grey[600],
                ),
                onPressed: () {
                  setState(
                    () => _obscureConfirmPassword = !_obscureConfirmPassword,
                  );
                },
              ),
            ],
          ),
          validator: (value) {
            if (value != _passwordController.text) {
              return 'Passwords do not match';
            }
            return null;
          },
          mobile: mobile,
        ),
      ],
    );
  }

  Widget _buildAdminVerificationSection({bool mobile = false}) {
    return Container(
      padding: EdgeInsets.all(mobile ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section title
          Row(
            children: [
              Icon(
                Icons.security,
                size: mobile ? 16 : 18,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(width: 8),
              Text(
                'Admin Verification',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                  fontSize: mobile ? 13 : 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Divider(color: AppTheme.primaryColor.withOpacity(0.2)),
          const SizedBox(height: 10),

          // Info message
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  size: mobile ? 14 : 16,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Please enter your admin password to confirm account creation. This keeps you signed in after creating the new account.',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: mobile ? 11 : 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Admin Email (read-only)
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: mobile ? 10 : 12,
            ),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.admin_panel_settings,
                  size: mobile ? 16 : 18,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Admin Email',
                        style: TextStyle(
                          fontSize: mobile ? 9 : 10,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        _adminEmail ?? 'Loading...',
                        style: TextStyle(
                          fontSize: mobile ? 13 : 14,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.lock,
                  size: mobile ? 14 : 16,
                  color: Colors.grey[400],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Admin Password
          _buildInputField(
            controller: _adminPasswordController,
            label: 'Your Admin Password',
            icon: Icons.key,
            obscureText: _obscureAdminPassword,
            focusNode: _adminPasswordFocus,
            suffixIcon: IconButton(
              icon: Icon(
                _obscureAdminPassword ? Icons.visibility_off : Icons.visibility,
                size: mobile ? 18 : 20,
                color: Colors.grey[600],
              ),
              onPressed: () {
                setState(() => _obscureAdminPassword = !_obscureAdminPassword);
              },
            ),
            validator: (value) {
              if (value?.isEmpty ?? true) {
                return 'Admin password is required';
              }
              return null;
            },
            mobile: mobile,
          ),
        ],
      ),
    );
  }

  Widget _buildMobileActions() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _createAccount,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              elevation: _isLoading ? 0 : 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              shadowColor: AppTheme.primaryColor.withOpacity(0.5),
            ),
            child:
                _isLoading
                    ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text('Creating Account...'),
                      ],
                    )
                    : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.person_add, size: 18),
                        SizedBox(width: 8),
                        Text('Create Account'),
                      ],
                    ),
          ),
        ),
      ),
    );
  }

  Widget _buildActions() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: _isLoading ? null : () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey[700],
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Cancel'),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: _isLoading ? null : _createAccount,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              elevation: _isLoading ? 0 : 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              shadowColor: AppTheme.primaryColor.withOpacity(0.5),
            ),
            child:
                _isLoading
                    ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        ),
                        SizedBox(width: 8),
                        Text('Creating...'),
                      ],
                    )
                    : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.person_add, size: 18),
                        SizedBox(width: 8),
                        Text('Create Account'),
                      ],
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
    FocusNode? focusNode,
    FocusNode? nextFocus,
    bool mobile = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Colors.white,
        border: Border.all(color: Colors.grey[400]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            spreadRadius: 1,
            blurRadius: 1,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            vertical: mobile ? 14 : 16,
            horizontal: mobile ? 8 : 16,
          ),
          prefixIcon: Icon(
            icon,
            color: Colors.grey[600],
            size: mobile ? 18 : 20,
          ),
          prefixIconConstraints: BoxConstraints(minWidth: mobile ? 40 : 52),
          suffixIcon: suffixIcon,
          floatingLabelBehavior: FloatingLabelBehavior.never,
          labelStyle: TextStyle(
            fontSize: mobile ? 13 : 14,
            color: Colors.grey[600],
          ),
        ),
        style: TextStyle(
          fontSize: mobile ? 13 : 14,
          color: AppTheme.textPrimary,
        ),
        keyboardType: keyboardType,
        obscureText: obscureText,
        validator: validator,
        focusNode: focusNode,
        onFieldSubmitted:
            nextFocus != null
                ? (_) {
                  FocusScope.of(context).requestFocus(nextFocus);
                }
                : null,
      ),
    );
  }
}
