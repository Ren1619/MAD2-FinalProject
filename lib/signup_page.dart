import 'package:flutter/material.dart';
import 'package:moneyger_finalproject/models/firebase_models.dart';
import 'package:provider/provider.dart';
import 'services/firebase_auth_service.dart';
import 'services/app_logger.dart';
import 'theme.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  _SignupPageState createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _formKey = GlobalKey<FormState>();
  final _pageController = PageController();
  final AppLogger _logger = AppLogger();

  // Admin user controllers
  final _adminFirstNameController = TextEditingController();
  final _adminLastNameController = TextEditingController();
  final _adminEmailController = TextEditingController();
  final _adminPasswordController = TextEditingController();
  final _adminConfirmPasswordController = TextEditingController();
  final _adminPhoneController = TextEditingController();

  // Company controllers
  final _companyNameController = TextEditingController();
  final _companyEmailController = TextEditingController();
  final _companyPhoneController = TextEditingController();
  final _companyAddressController = TextEditingController();
  final _companyCityController = TextEditingController();
  final _companyStateController = TextEditingController();
  final _companyZipController = TextEditingController();
  final _companyWebsiteController = TextEditingController();

  int _currentStep = 0;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreeToTerms = false;

  String _companySize = '1-10 employees';
  String _industryType = 'Information Technology';

  final List<String> _companySizes = [
    '1-10 employees',
    '11-50 employees',
    '51-200 employees',
    '201-500 employees',
    '501-1000 employees',
    '1000+ employees',
  ];

  final List<String> _industryTypes = [
    'Information Technology',
    'Healthcare',
    'Finance',
    'Education',
    'Manufacturing',
    'Retail',
    'Real Estate',
    'Transportation',
    'Entertainment',
    'Hospitality',
    'Construction',
    'Agriculture',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _logPageAccess();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _adminFirstNameController.dispose();
    _adminLastNameController.dispose();
    _adminEmailController.dispose();
    _adminPasswordController.dispose();
    _adminConfirmPasswordController.dispose();
    _adminPhoneController.dispose();
    _companyNameController.dispose();
    _companyEmailController.dispose();
    _companyPhoneController.dispose();
    _companyAddressController.dispose();
    _companyCityController.dispose();
    _companyStateController.dispose();
    _companyZipController.dispose();
    _companyWebsiteController.dispose();
    super.dispose();
  }

  void _logPageAccess() {
    _logger.info(
      'Company registration page accessed',
      category: LogCategory.accountManagement,
      data: {
        'timestamp': DateTime.now().toIso8601String(),
        'user_agent': 'Flutter App',
        'registration_type': 'company_with_admin',
      },
    );
  }

  void _nextStep() {
    _logger.logUserAction(
      'Registration step navigation attempted',
      data: {
        'current_step': _currentStep,
        'target_step': _currentStep + 1,
        'step_name': _getStepName(_currentStep),
      },
    );

    if (_currentStep < 2) {
      // Validate current step
      if (_currentStep == 0 && !_validateAdminInfo()) {
        _logger.warning(
          'Registration step validation failed - admin info',
          category: LogCategory.accountManagement,
          data: {
            'current_step': _currentStep,
            'validation_type': 'admin_information',
            'admin_email': _adminEmailController.text.trim(),
          },
        );
        return;
      }
      if (_currentStep == 1 && !_validateCompanyInfo()) {
        _logger.warning(
          'Registration step validation failed - company info',
          category: LogCategory.accountManagement,
          data: {
            'current_step': _currentStep,
            'validation_type': 'company_information',
            'company_name': _companyNameController.text.trim(),
            'company_email': _companyEmailController.text.trim(),
          },
        );
        return;
      }

      setState(() {
        _currentStep++;
      });
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );

      _logger.logUserAction(
        'Registration step navigation successful',
        data: {
          'new_step': _currentStep,
          'step_name': _getStepName(_currentStep),
          'navigation_direction': 'forward',
        },
      );
    } else {
      // Final step - submit registration
      _logger.info(
        'Registration submission initiated',
        category: LogCategory.accountManagement,
        data: {
          'admin_email': _adminEmailController.text.trim(),
          'company_name': _companyNameController.text.trim(),
          'company_email': _companyEmailController.text.trim(),
          'company_size': _companySize,
          'industry': _industryType,
        },
      );
      _handleRegistration();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      _logger.logUserAction(
        'Registration step navigation - previous',
        data: {
          'current_step': _currentStep,
          'target_step': _currentStep - 1,
          'navigation_direction': 'backward',
        },
      );

      setState(() {
        _currentStep--;
      });
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  String _getStepName(int step) {
    switch (step) {
      case 0:
        return 'Administrator Details';
      case 1:
        return 'Company Information';
      case 2:
        return 'Review & Confirm';
      default:
        return 'Unknown Step';
    }
  }

  bool _validateAdminInfo() {
    List<String> validationErrors = [];

    // Validate admin information
    if (_adminFirstNameController.text.trim().isEmpty) {
      validationErrors.add('First name is empty');
      _showErrorSnackBar('Please enter your first name');
      return false;
    }

    if (_adminLastNameController.text.trim().isEmpty) {
      validationErrors.add('Last name is empty');
      _showErrorSnackBar('Please enter your last name');
      return false;
    }

    if (_adminEmailController.text.trim().isEmpty ||
        !RegExp(
          r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
        ).hasMatch(_adminEmailController.text.trim())) {
      validationErrors.add('Invalid email format');
      _showErrorSnackBar('Please enter a valid email address');
      return false;
    }

    if (_adminPasswordController.text.isEmpty ||
        _adminPasswordController.text.length < 6) {
      validationErrors.add('Password too short');
      _showErrorSnackBar('Password must be at least 6 characters long');
      return false;
    }

    if (_adminPasswordController.text != _adminConfirmPasswordController.text) {
      validationErrors.add('Passwords do not match');
      _showErrorSnackBar('Passwords do not match');
      return false;
    }

    _logger.debug(
      'Admin information validation successful',
      category: LogCategory.accountManagement,
      data: {
        'admin_email': _adminEmailController.text.trim(),
        'has_phone': _adminPhoneController.text.trim().isNotEmpty,
        'password_length': _adminPasswordController.text.length,
      },
    );

    return true;
  }

  bool _validateCompanyInfo() {
    List<String> validationErrors = [];

    // Validate company information
    if (_companyNameController.text.trim().isEmpty) {
      validationErrors.add('Company name is empty');
      _showErrorSnackBar('Please enter your company name');
      return false;
    }

    if (_companyEmailController.text.trim().isEmpty ||
        !RegExp(
          r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
        ).hasMatch(_companyEmailController.text.trim())) {
      validationErrors.add('Invalid company email');
      _showErrorSnackBar('Please enter a valid company email address');
      return false;
    }

    _logger.debug(
      'Company information validation successful',
      category: LogCategory.accountManagement,
      data: {
        'company_name': _companyNameController.text.trim(),
        'company_email': _companyEmailController.text.trim(),
        'has_phone': _companyPhoneController.text.trim().isNotEmpty,
        'has_website': _companyWebsiteController.text.trim().isNotEmpty,
        'has_address': _companyAddressController.text.trim().isNotEmpty,
        'company_size': _companySize,
        'industry': _industryType,
      },
    );

    return true;
  }

  void _handleRegistration() async {
    // Final validation
    if (!_validateCompanyInfo()) {
      return;
    }

    if (!_agreeToTerms) {
      _logger.logSecurity(
        'Registration attempt without terms agreement',
        level: LogLevel.warning,
        data: {
          'admin_email': _adminEmailController.text.trim(),
          'company_name': _companyNameController.text.trim(),
          'terms_accepted': false,
        },
      );

      _showErrorSnackBar(
        'You must agree to the Terms of Service and Privacy Policy',
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final adminEmail = _adminEmailController.text.trim();
    final companyName = _companyNameController.text.trim();
    final companyEmail = _companyEmailController.text.trim();

    await _logger.timeOperation(
      'Company Registration Process',
      () async {
        try {
          await _logger.info(
            'Starting company registration process',
            category: LogCategory.accountManagement,
            data: {
              'admin_email': adminEmail,
              'admin_name':
                  '${_adminFirstNameController.text.trim()} ${_adminLastNameController.text.trim()}',
              'company_name': companyName,
              'company_email': companyEmail,
              'company_size': _companySize,
              'industry': _industryType,
              'has_admin_phone': _adminPhoneController.text.trim().isNotEmpty,
              'has_company_phone':
                  _companyPhoneController.text.trim().isNotEmpty,
              'has_company_website':
                  _companyWebsiteController.text.trim().isNotEmpty,
              'has_company_address':
                  _companyAddressController.text.trim().isNotEmpty,
              'terms_accepted': _agreeToTerms,
            },
          );

          final firebaseAuthService = Provider.of<FirebaseAuthService>(
            context,
            listen: false,
          );

          // Create company object
          final company = Company(
            companyId: '', // Will be generated by the service
            companyName: companyName,
            email: companyEmail,
            phone: _companyPhoneController.text.trim(),
            address: _companyAddressController.text.trim(),
            city: _companyCityController.text.trim(),
            state: _companyStateController.text.trim(),
            zipcode: _companyZipController.text.trim(),
            website: _companyWebsiteController.text.trim(),
            size: _companySize,
            industry: _industryType,
            createdAt: DateTime.now(),
          );

          await _logger.debug(
            'Company object created, calling registration service',
            category: LogCategory.accountManagement,
            data: {'company_data_prepared': true, 'admin_data_prepared': true},
          );

          // Register company with admin
          final success = await firebaseAuthService.registerCompanyWithAdmin(
            company: company,
            adminName:
                '${_adminFirstNameController.text.trim()} ${_adminLastNameController.text.trim()}',
            adminEmail: adminEmail,
            adminPassword: _adminPasswordController.text,
            adminPhone: _adminPhoneController.text.trim(),
          );

          if (success) {
            await _logger.logAccountManagement(
              'Company registration completed successfully',
              targetEmail: adminEmail,
              data: {
                'company_name': companyName,
                'company_email': companyEmail,
                'admin_email': adminEmail,
                'company_size': _companySize,
                'industry': _industryType,
                'registration_method': 'self_registration',
                'has_admin_phone': _adminPhoneController.text.trim().isNotEmpty,
                'has_company_address':
                    _companyAddressController.text.trim().isNotEmpty,
              },
            );

            // Show success message
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                  'Registration successful! You can now sign in.',
                ),
                backgroundColor: Colors.green[700],
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                duration: const Duration(seconds: 5),
              ),
            );

            await _logger.logUserAction(
              'Navigating to login after successful registration',
              data: {
                'source_page': 'company_registration',
                'target_route': '/login',
                'navigation_type': 'pushReplacement',
                'registration_success': true,
              },
            );

            // Navigate to login page
            Navigator.of(context).pushReplacementNamed('/login');
          } else {
            await _logger.error(
              'Company registration failed - service returned false',
              category: LogCategory.accountManagement,
              data: {
                'admin_email': adminEmail,
                'company_name': companyName,
                'company_email': companyEmail,
                'failure_reason': 'Service returned false',
              },
            );

            _showErrorSnackBar('Registration failed. Please try again.');
          }
        } catch (e) {
          await _logger.error(
            'Company registration failed with exception',
            category: LogCategory.accountManagement,
            error: e,
            data: {
              'admin_email': adminEmail,
              'company_name': companyName,
              'company_email': companyEmail,
              'error_type': e.runtimeType.toString(),
            },
          );

          String errorMessage = e.toString();

          // Handle Firebase Auth specific errors
          if (errorMessage.contains('email-already-in-use')) {
            errorMessage = 'An account with this email address already exists.';

            await _logger.logSecurity(
              'Registration attempt with existing email',
              level: LogLevel.warning,
              data: {
                'admin_email': adminEmail,
                'company_name': companyName,
                'conflict_type': 'email_already_exists',
              },
            );
          } else if (errorMessage.contains('weak-password')) {
            errorMessage =
                'The password is too weak. Please choose a stronger password.';

            await _logger.warning(
              'Registration failed due to weak password',
              category: LogCategory.accountManagement,
              data: {
                'admin_email': adminEmail,
                'password_length': _adminPasswordController.text.length,
              },
            );
          } else if (errorMessage.contains('invalid-email')) {
            errorMessage = 'Please enter a valid email address.';

            await _logger.warning(
              'Registration failed due to invalid email format',
              category: LogCategory.accountManagement,
              data: {
                'attempted_email': adminEmail,
                'validation_error': 'invalid_email_format',
              },
            );
          }

          _showErrorSnackBar(errorMessage);
        } finally {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
        }
      },
      data: {
        'admin_email': adminEmail,
        'company_name': companyName,
        'operation': 'company_registration',
      },
    );
  }

  void _handleTermsAgreementChange(bool? value) {
    setState(() {
      _agreeToTerms = value ?? false;
    });

    _logger.logUserAction(
      'Terms agreement toggled',
      data: {
        'terms_accepted': _agreeToTerms,
        'admin_email': _adminEmailController.text.trim(),
        'company_name': _companyNameController.text.trim(),
      },
    );
  }

  void _handlePasswordVisibilityToggle(bool isConfirmPassword) {
    setState(() {
      if (isConfirmPassword) {
        _obscureConfirmPassword = !_obscureConfirmPassword;
      } else {
        _obscurePassword = !_obscurePassword;
      }
    });

    _logger.logUserAction(
      'Password visibility toggled',
      data: {
        'field_type': isConfirmPassword ? 'confirm_password' : 'password',
        'is_visible':
            isConfirmPassword ? !_obscureConfirmPassword : !_obscurePassword,
      },
    );
  }

  void _handleCompanySizeChange(String? value) {
    if (value != null) {
      setState(() {
        _companySize = value;
      });

      _logger.logUserAction(
        'Company size selection changed',
        data: {
          'selected_size': value,
          'company_name': _companyNameController.text.trim(),
        },
      );
    }
  }

  void _handleIndustryChange(String? value) {
    if (value != null) {
      setState(() {
        _industryType = value;
      });

      _logger.logUserAction(
        'Industry type selection changed',
        data: {
          'selected_industry': value,
          'company_name': _companyNameController.text.trim(),
        },
      );
    }
  }

  void _handleEditStep(int targetStep) {
    _logger.logUserAction(
      'Registration review - edit step requested',
      data: {
        'current_step': _currentStep,
        'target_step': targetStep,
        'edit_action': 'review_page_edit',
      },
    );

    setState(() {
      _currentStep = targetStep;
    });
    _pageController.animateToPage(
      targetStep,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _showErrorSnackBar(String message) {
    _logger.logUserAction(
      'Error message displayed to user',
      data: {
        'error_message': message,
        'display_method': 'snackbar',
        'current_step': _currentStep,
      },
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final bool isDesktop = screenSize.width > 800;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: AppTheme.primaryColor),
        title: Text(
          'Register Your Company',
          style: TextStyle(
            color: AppTheme.primaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppTheme.primaryColor),
          onPressed: () {
            _logger.logUserAction(
              'Registration page - back navigation',
              data: {
                'current_step': _currentStep,
                'navigation_target': 'login_page',
              },
            );
            Navigator.pop(context);
          },
        ),
      ),
      body: SafeArea(
        child: Row(
          children: [
            // Left panel with steps (on larger screens)
            if (isDesktop)
              Container(
                width: screenSize.width * 0.25,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [AppTheme.primaryColor, AppTheme.primaryDarkColor],
                  ),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 40),
                    // Logo
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.business,
                        size: 60,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Company Registration',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'Register your company and create your administrator account',
                        style: TextStyle(
                          color: AppTheme.primaryLightColor,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 48),
                    // Steps
                    _buildStepItem(0, 'Administrator Details'),
                    _buildStepItem(1, 'Company Information'),
                    _buildStepItem(2, 'Review & Confirm'),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Need help? Contact support@budgetapp.com',
                        style: TextStyle(
                          color: AppTheme.primaryLightColor,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),

            // Main content area
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 48.0 : 24.0,
                  vertical: 24.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header (only on mobile)
                    if (!isDesktop) ...[
                      _buildMobileStepIndicator(),
                      const SizedBox(height: 24),
                    ],

                    // Form pages
                    Expanded(
                      child: Form(
                        key: _formKey,
                        child: PageView(
                          controller: _pageController,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            _buildAdminInfoForm(),
                            _buildCompanyInfoForm(),
                            _buildReviewPage(),
                          ],
                        ),
                      ),
                    ),

                    // Navigation buttons
                    _buildNavigationButtons(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepItem(int step, String title) {
    final isActive = step == _currentStep;
    final isCompleted = step < _currentStep;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
      child: Row(
        children: [
          // Step indicator
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color:
                  isActive || isCompleted
                      ? Colors.white
                      : Colors.white.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: Center(
              child:
                  isCompleted
                      ? Icon(
                        Icons.check,
                        color: AppTheme.primaryColor,
                        size: 16,
                      )
                      : Text(
                        '${step + 1}',
                        style: TextStyle(
                          color:
                              isActive ? AppTheme.primaryColor : Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              color:
                  isActive || isCompleted
                      ? Colors.white
                      : Colors.white.withOpacity(0.7),
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileStepIndicator() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          [
            'Administrator Details',
            'Company Information',
            'Review & Confirm',
          ][_currentStep],
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryColor,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Step ${_currentStep + 1} of 3',
          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
        ),
        const SizedBox(height: 16),
        LinearProgressIndicator(
          value: (_currentStep + 1) / 3,
          backgroundColor: Colors.grey[200],
          color: AppTheme.primaryColor,
          minHeight: 6,
        ),
      ],
    );
  }

  Widget _buildAdminInfoForm() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (MediaQuery.of(context).size.width > 800) ...[
            Text(
              'Administrator Information',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create the main administrator account for your company',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 32),
          ],

          // First Name
          TextFormField(
            controller: _adminFirstNameController,
            decoration: const InputDecoration(
              labelText: 'First Name',
              hintText: 'Enter your first name',
              prefixIcon: Icon(Icons.person),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your first name';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Last Name
          TextFormField(
            controller: _adminLastNameController,
            decoration: const InputDecoration(
              labelText: 'Last Name',
              hintText: 'Enter your last name',
              prefixIcon: Icon(Icons.person),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your last name';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Email
          TextFormField(
            controller: _adminEmailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email Address',
              hintText: 'Enter your email address',
              prefixIcon: Icon(Icons.email),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your email address';
              }
              if (!RegExp(
                r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
              ).hasMatch(value.trim())) {
                return 'Please enter a valid email address';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Phone (optional)
          TextFormField(
            controller: _adminPhoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Phone Number (Optional)',
              hintText: 'Enter your phone number',
              prefixIcon: Icon(Icons.phone),
            ),
          ),
          const SizedBox(height: 24),

          // Role information
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryLightColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.admin_panel_settings, color: AppTheme.primaryColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Administrator Account',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Your account will have full administrative privileges to manage your company\'s budget system',
                        style: TextStyle(color: AppTheme.primaryColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Password
          TextFormField(
            controller: _adminPasswordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Password',
              hintText: 'Create a secure password',
              prefixIcon: const Icon(Icons.lock),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () => _handlePasswordVisibilityToggle(false),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a password';
              }
              if (value.length < 6) {
                return 'Password must be at least 6 characters long';
              }
              return null;
            },
          ),
          const SizedBox(height: 8),
          Text(
            'Password must be at least 6 characters long',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),

          // Confirm Password
          TextFormField(
            controller: _adminConfirmPasswordController,
            obscureText: _obscureConfirmPassword,
            decoration: InputDecoration(
              labelText: 'Confirm Password',
              hintText: 'Confirm your password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPassword
                      ? Icons.visibility_off
                      : Icons.visibility,
                ),
                onPressed: () => _handlePasswordVisibilityToggle(true),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please confirm your password';
              }
              if (value != _adminPasswordController.text) {
                return 'Passwords do not match';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCompanyInfoForm() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (MediaQuery.of(context).size.width > 800) ...[
            Text(
              'Company Information',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Provide details about your company',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 32),
          ],

          // Company Name
          TextFormField(
            controller: _companyNameController,
            decoration: const InputDecoration(
              labelText: 'Company Name',
              hintText: 'Enter your company name',
              prefixIcon: Icon(Icons.business),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your company name';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Company Email
          TextFormField(
            controller: _companyEmailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Company Email',
              hintText: 'Enter company email address',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter company email address';
              }
              if (!RegExp(
                r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
              ).hasMatch(value.trim())) {
                return 'Please enter a valid email address';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Company Phone
          TextFormField(
            controller: _companyPhoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Company Phone',
              hintText: 'Enter company phone number',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
          ),
          const SizedBox(height: 16),

          // Website (optional)
          TextFormField(
            controller: _companyWebsiteController,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'Company Website (Optional)',
              hintText: 'Enter company website',
              prefixIcon: Icon(Icons.language),
            ),
          ),
          const SizedBox(height: 24),

          // Address Section
          Text(
            'Company Address',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 12),

          // Street Address
          TextFormField(
            controller: _companyAddressController,
            decoration: const InputDecoration(
              labelText: 'Street Address',
              hintText: 'Enter street address',
            ),
          ),
          const SizedBox(height: 16),

          // City, State, Zip
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 600) {
                return Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _companyCityController,
                        decoration: const InputDecoration(
                          labelText: 'City',
                          hintText: 'Enter city',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _companyStateController,
                        decoration: const InputDecoration(
                          labelText: 'State/Province',
                          hintText: 'Enter state',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 120,
                      child: TextFormField(
                        controller: _companyZipController,
                        decoration: const InputDecoration(
                          labelText: 'Zip/Postal',
                          hintText: 'Enter zip',
                        ),
                      ),
                    ),
                  ],
                );
              } else {
                return Column(
                  children: [
                    TextFormField(
                      controller: _companyCityController,
                      decoration: const InputDecoration(
                        labelText: 'City',
                        hintText: 'Enter city',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _companyStateController,
                      decoration: const InputDecoration(
                        labelText: 'State/Province',
                        hintText: 'Enter state',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _companyZipController,
                      decoration: const InputDecoration(
                        labelText: 'Zip/Postal',
                        hintText: 'Enter zip',
                      ),
                    ),
                  ],
                );
              }
            },
          ),
          const SizedBox(height: 24),

          // Company Details Section
          Text(
            'Company Details',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 12),

          // Company Size
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(
              labelText: 'Company Size',
              prefixIcon: Icon(Icons.people),
            ),
            value: _companySize,
            items:
                _companySizes.map((size) {
                  return DropdownMenuItem<String>(
                    value: size,
                    child: Text(size),
                  );
                }).toList(),
            onChanged: _handleCompanySizeChange,
          ),
          const SizedBox(height: 16),

          // Industry Type
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(
              labelText: 'Industry',
              prefixIcon: Icon(Icons.domain),
            ),
            value: _industryType,
            items:
                _industryTypes.map((industry) {
                  return DropdownMenuItem<String>(
                    value: industry,
                    child: Text(industry),
                  );
                }).toList(),
            onChanged: _handleIndustryChange,
          ),
        ],
      ),
    );
  }

  Widget _buildReviewPage() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (MediaQuery.of(context).size.width > 800) ...[
            Text(
              'Review & Confirm',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please review your information before completing registration',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 32),
          ],

          // Administrator Information Card
          _buildInfoCard(
            title: 'Administrator Information',
            icon: Icons.person,
            onEdit: () => _handleEditStep(0),
            children: [
              _buildReviewItem('First Name', _adminFirstNameController.text),
              _buildReviewItem('Last Name', _adminLastNameController.text),
              _buildReviewItem('Email', _adminEmailController.text),
              _buildReviewItem(
                'Phone',
                _adminPhoneController.text.isEmpty
                    ? 'Not provided'
                    : _adminPhoneController.text,
              ),
              _buildReviewItem('Role', 'Administrator'),
            ],
          ),

          const SizedBox(height: 16),

          // Company Information Card
          _buildInfoCard(
            title: 'Company Information',
            icon: Icons.business,
            onEdit: () => _handleEditStep(1),
            children: [
              _buildReviewItem('Company Name', _companyNameController.text),
              _buildReviewItem('Email', _companyEmailController.text),
              _buildReviewItem(
                'Phone',
                _companyPhoneController.text.isEmpty
                    ? 'Not provided'
                    : _companyPhoneController.text,
              ),
              _buildReviewItem(
                'Website',
                _companyWebsiteController.text.isEmpty
                    ? 'Not provided'
                    : _companyWebsiteController.text,
              ),
              _buildReviewItem('Address', _formatAddress()),
              _buildReviewItem('Company Size', _companySize),
              _buildReviewItem('Industry', _industryType),
            ],
          ),

          const SizedBox(height: 24),

          // Terms and Conditions
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: _agreeToTerms,
                onChanged: _handleTermsAgreementChange,
                activeColor: AppTheme.primaryColor,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(fontSize: 14, color: Colors.grey[800]),
                      children: [
                        const TextSpan(text: 'I agree to the '),
                        TextSpan(
                          text: 'Terms of Service',
                          style: TextStyle(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                        const TextSpan(text: ' and '),
                        TextSpan(
                          text: 'Privacy Policy',
                          style: TextStyle(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required VoidCallback onEdit,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const Spacer(),
                TextButton(onPressed: onEdit, child: const Text('Edit')),
              ],
            ),
            const Divider(),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildReviewItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: TextStyle(color: Colors.grey[900])),
          ),
        ],
      ),
    );
  }

  String _formatAddress() {
    List<String> parts = [];

    if (_companyAddressController.text.isNotEmpty) {
      parts.add(_companyAddressController.text);
    }

    String cityStateZip = '';
    if (_companyCityController.text.isNotEmpty) {
      cityStateZip += _companyCityController.text;
    }

    if (_companyStateController.text.isNotEmpty) {
      cityStateZip +=
          cityStateZip.isNotEmpty
              ? ', ${_companyStateController.text}'
              : _companyStateController.text;
    }

    if (_companyZipController.text.isNotEmpty) {
      cityStateZip +=
          cityStateZip.isNotEmpty
              ? ' ${_companyZipController.text}'
              : _companyZipController.text;
    }

    if (cityStateZip.isNotEmpty) {
      parts.add(cityStateZip);
    }

    return parts.isEmpty ? 'Not provided' : parts.join('\n');
  }

  Widget _buildNavigationButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (_currentStep > 0)
          OutlinedButton(
            onPressed: _isLoading ? null : _previousStep,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              side: BorderSide(color: AppTheme.primaryColor.withOpacity(0.5)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.arrow_back, size: 16),
                const SizedBox(width: 8),
                const Text('Previous'),
              ],
            ),
          )
        else
          const SizedBox(),

        ElevatedButton(
          onPressed: _isLoading ? null : _nextStep,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            disabledBackgroundColor: AppTheme.primaryColor.withOpacity(0.6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_currentStep < 2 ? 'Next' : 'Complete Registration'),
              const SizedBox(width: 8),
              _isLoading
                  ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                  : Icon(
                    _currentStep < 2 ? Icons.arrow_forward : Icons.check_circle,
                    size: 16,
                  ),
            ],
          ),
        ),
      ],
    );
  }
}
