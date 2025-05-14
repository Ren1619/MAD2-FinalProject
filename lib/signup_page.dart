import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'services/auth_service.dart';
import 'services/database_service.dart';
import 'widgets/common_widgets.dart';
import 'theme.dart';
import 'models/company_model.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({Key? key}) : super(key: key);

  @override
  _SignupPageState createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();
  final PageController _pageController = PageController();

  // Admin user details
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _phoneController = TextEditingController();
  // Remove the _selectedRole variable as the role will always be Company Admin

  // Company details
  final _companyNameController = TextEditingController();
  final _companyEmailController = TextEditingController();
  final _companyPhoneController = TextEditingController();
  final _companyAddressController = TextEditingController();
  final _companyCityController = TextEditingController();
  final _companyStateController = TextEditingController();
  final _companyZipController = TextEditingController();
  final _companyWebsiteController = TextEditingController();
  String _companySize = '1-10 employees';
  String _industryType = 'Information Technology';

  int _currentStep = 0;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _agreeToTerms = false;
  bool _enableNotifications = true;

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
  void dispose() {
    _scrollController.dispose();
    _pageController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
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

  void _nextStep() {
    if (_currentStep < 2) {
      // Validate current step
      if (_currentStep == 0) {
        // Validate admin information
        if (!_validateAdminInfo()) {
          return;
        }
      }
      setState(() {
        _currentStep++;
      });
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // Final step - submit form
      _handleSignup();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
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

  bool _validateAdminInfo() {
    // Validate admin info fields
    if (_nameController.text.isEmpty) {
      _showErrorSnackbar('Please enter your name');
      return false;
    }

    if (_emailController.text.isEmpty ||
        !RegExp(
          r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
        ).hasMatch(_emailController.text)) {
      _showErrorSnackbar('Please enter a valid email address');
      return false;
    }

    if (_passwordController.text.isEmpty ||
        _passwordController.text.length < 6) {
      _showErrorSnackbar('Password must be at least 6 characters');
      return false;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      _showErrorSnackbar('Passwords do not match');
      return false;
    }

    return true;
  }

  bool _validateCompanyInfo() {
    // Validate company info fields
    if (_companyNameController.text.isEmpty) {
      _showErrorSnackbar('Please enter your company name');
      return false;
    }

    if (_companyEmailController.text.isEmpty ||
        !RegExp(
          r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
        ).hasMatch(_companyEmailController.text)) {
      _showErrorSnackbar('Please enter a valid company email address');
      return false;
    }

    return true;
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _handleSignup() async {
    // Validate company information
    if (!_validateCompanyInfo()) {
      return;
    }

    // Validate terms agreement
    if (!_agreeToTerms) {
      _showErrorSnackbar('You must agree to the Terms of Service');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Get database and auth services
      final databaseService = Provider.of<DatabaseService>(
        context,
        listen: false,
      );
      final authService = AuthService();

      // Create company object
      final company = Company(
        id: '', // Will be set by the database service
        name: _companyNameController.text,
        email: _companyEmailController.text,
        phone: _companyPhoneController.text,
        address: _companyAddressController.text,
        city: _companyCityController.text,
        state: _companyStateController.text,
        zipcode: _companyZipController.text,
        website: _companyWebsiteController.text,
        size: _companySize,
        industry: _industryType,
        createdAt: DateTime.now().toIso8601String(),
      );

      // Register the company and admin user
      // Note: we're now using ROLE_COMPANY_ADMIN constant for the admin role
      final success = await authService.registerCompanyAndAdmin(
        company: company,
        adminName: _nameController.text,
        adminEmail: _emailController.text,
        adminPassword: _passwordController.text,
        adminRole:
            AuthService.ROLE_COMPANY_ADMIN, // Always register as Company Admin
        adminPhone: _phoneController.text,
        enableNotifications: _enableNotifications,
      );

      if (success) {
        // Log activity
        await databaseService.logActivity(
          'New company registered: ${_companyNameController.text}',
          'Account Management',
        );

        // Navigate to login page
        Navigator.pushReplacementNamed(context, '/login');

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Registration successful! Please log in.'),
            backgroundColor: Colors.green[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      } else {
        _showErrorSnackbar('Registration failed. Email may already be in use.');
      }
    } catch (e) {
      _showErrorSnackbar('Error during registration: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
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
          'Register your company',
          style: TextStyle(
            color: AppTheme.primaryColor,
            fontWeight: FontWeight.bold,
          ),
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
                    colors: [Colors.blue[700]!, Colors.blue[900]!],
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
                        Icons.account_balance_wallet,
                        size: 60,
                        color: Colors.blue[700],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Budget Management',
                      style: const TextStyle(
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
                        'Complete the registration to gain access to our platform',
                        style: TextStyle(color: Colors.blue[100], fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 48),
                    // Steps
                    _buildStepItem(0, 'Admin Information'),
                    _buildStepItem(1, 'Company Details'),
                    _buildStepItem(2, 'Review & Confirm'),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Need help? Contact support@budgetapp.com',
                        style: TextStyle(color: Colors.blue[100], fontSize: 12),
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

                    // Bottom navigation buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (_currentStep > 0)
                          OutlinedButton(
                            onPressed: _isLoading ? null : _previousStep,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.blue[700],
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              side: BorderSide(color: Colors.blue[300]!),
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
                          const SizedBox(), // Empty widget for spacing

                        ElevatedButton(
                          onPressed: _isLoading ? null : _nextStep,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[700],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            disabledBackgroundColor: Colors.blue[300],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _currentStep < 2
                                    ? 'Next'
                                    : 'Complete Registration',
                              ),
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
                                    _currentStep < 2
                                        ? Icons.arrow_forward
                                        : Icons.check_circle,
                                    size: 16,
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
                      ? Icon(Icons.check, color: Colors.blue[700], size: 16)
                      : Text(
                        '${step + 1}',
                        style: TextStyle(
                          color: isActive ? Colors.blue[700] : Colors.white,
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
            'Admin Information',
            'Company Details',
            'Review & Confirm',
          ][_currentStep],
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.blue[800],
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
          color: Colors.blue[700],
          minHeight: 6,
          borderRadius: BorderRadius.circular(3),
        ),
      ],
    );
  }

  Widget _buildAdminInfoForm() {
    return SingleChildScrollView(
      controller: _scrollController,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (MediaQuery.of(context).size.width > 800) ...[
            Text(
              'Admin Information',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.blue[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please provide details for the main administrator account',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 32),
          ],

          // Full Name
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Full Name',
              hintText: 'Enter your full name',
              prefixIcon: const Icon(Icons.person),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Email
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'Email Address',
              hintText: 'Enter your email address',
              prefixIcon: const Icon(Icons.email),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Phone
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'Phone Number (Optional)',
              hintText: 'Enter your phone number',
              prefixIcon: const Icon(Icons.phone),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Display the role as read-only information
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.admin_panel_settings, color: Colors.blue[700]),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Administrator Role',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[800],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Your account will be created with full administrator privileges',
                        style: TextStyle(color: Colors.blue[800]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Password
          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Password',
              hintText: 'Create a password',
              prefixIcon: const Icon(Icons.lock),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Password must be at least 6 characters',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),

          // Confirm Password
          TextField(
            controller: _confirmPasswordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Confirm Password',
              hintText: 'Confirm your password',
              prefixIcon: const Icon(Icons.lock_outline),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Notifications toggle
          Row(
            children: [
              Switch(
                value: _enableNotifications,
                onChanged: (value) {
                  setState(() {
                    _enableNotifications = value;
                  });
                },
                activeColor: Colors.blue[700],
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Receive notifications about budget updates and account activities',
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildCompanyInfoForm() {
    return SingleChildScrollView(
      controller: _scrollController,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (MediaQuery.of(context).size.width > 800) ...[
            Text(
              'Company Details',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.blue[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please provide information about your company',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 32),
          ],

          // Company Name
          TextField(
            controller: _companyNameController,
            decoration: InputDecoration(
              labelText: 'Company Name',
              hintText: 'Enter your company name',
              prefixIcon: const Icon(Icons.business),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Company Email
          TextField(
            controller: _companyEmailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'Company Email',
              hintText: 'Enter company email address',
              prefixIcon: const Icon(Icons.email_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Company Phone
          TextField(
            controller: _companyPhoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'Company Phone',
              hintText: 'Enter company phone number',
              prefixIcon: const Icon(Icons.phone_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Company Website
          TextField(
            controller: _companyWebsiteController,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              labelText: 'Company Website (Optional)',
              hintText: 'Enter company website',
              prefixIcon: const Icon(Icons.language),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Address
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
          TextField(
            controller: _companyAddressController,
            decoration: InputDecoration(
              labelText: 'Street Address',
              hintText: 'Enter street address',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // City, State, Zip in a row for wider screens, stacked for mobile
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 600) {
                return Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _companyCityController,
                        decoration: InputDecoration(
                          labelText: 'City',
                          hintText: 'Enter city',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _companyStateController,
                        decoration: InputDecoration(
                          labelText: 'State/Province',
                          hintText: 'Enter state',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 120,
                      child: TextField(
                        controller: _companyZipController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Zip/Postal',
                          hintText: 'Enter zip',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              } else {
                return Column(
                  children: [
                    TextField(
                      controller: _companyCityController,
                      decoration: InputDecoration(
                        labelText: 'City',
                        hintText: 'Enter city',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _companyStateController,
                      decoration: InputDecoration(
                        labelText: 'State/Province',
                        hintText: 'Enter state',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _companyZipController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Zip/Postal',
                        hintText: 'Enter zip',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                );
              }
            },
          ),
          const SizedBox(height: 24),

          // Company Size and Industry
          Text(
            'Company Information',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 12),

          // Company Size dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(10),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _companySize,
                isExpanded: true,
                hint: const Text('Select company size'),
                icon: const Icon(Icons.arrow_drop_down),
                items:
                    _companySizes.map((String size) {
                      return DropdownMenuItem<String>(
                        value: size,
                        child: Text(size),
                      );
                    }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _companySize = newValue;
                    });
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Industry dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(10),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _industryType,
                isExpanded: true,
                hint: const Text('Select industry'),
                icon: const Icon(Icons.arrow_drop_down),
                items:
                    _industryTypes.map((String industry) {
                      return DropdownMenuItem<String>(
                        value: industry,
                        child: Text(industry),
                      );
                    }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _industryType = newValue;
                    });
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildReviewPage() {
    return SingleChildScrollView(
      controller: _scrollController,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (MediaQuery.of(context).size.width > 800) ...[
            Text(
              'Review & Confirm',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.blue[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please review your information before completing registration',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 32),
          ],

          // Admin Information Card
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.person, color: Colors.blue[700]),
                      const SizedBox(width: 8),
                      Text(
                        'Admin Information',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[800],
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _currentStep = 0;
                          });
                          _pageController.animateToPage(
                            0,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                        child: const Text('Edit'),
                      ),
                    ],
                  ),
                  const Divider(),
                  _buildReviewItem('Name', _nameController.text),
                  _buildReviewItem('Email', _emailController.text),
                  _buildReviewItem(
                    'Phone',
                    _phoneController.text.isEmpty
                        ? 'Not provided'
                        : _phoneController.text,
                  ),
                  _buildReviewItem('Role', 'Company Admin'), // Fixed role
                ],
              ),
            ),
          ), 
          const SizedBox(height: 16),

          // Company Information Card
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.business, color: Colors.blue[700]),
                      const SizedBox(width: 8),
                      Text(
                        'Company Information',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[800],
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _currentStep = 1;
                          });
                          _pageController.animateToPage(
                            1,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                        child: const Text('Edit'),
                      ),
                    ],
                  ),
                  const Divider(),
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
            ),
          ),
          const SizedBox(height: 24),

          // Terms and Conditions
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: _agreeToTerms,
                onChanged: (value) {
                  setState(() {
                    _agreeToTerms = value ?? false;
                  });
                },
                activeColor: Colors.blue[700],
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
                            color: Colors.blue[700],
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                        const TextSpan(text: ' and '),
                        TextSpan(
                          text: 'Privacy Policy',
                          style: TextStyle(
                            color: Colors.blue[700],
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
          const SizedBox(height: 24),
        ],
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
}
