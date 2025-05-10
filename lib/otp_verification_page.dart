import 'package:flutter/material.dart';
import 'services/database_service.dart';
import 'theme.dart';
import 'widgets/common_widgets.dart';

class OtpVerificationPage extends StatefulWidget {
  final String email;

  const OtpVerificationPage({super.key, required this.email});

  @override
  _OtpVerificationPageState createState() => _OtpVerificationPageState();
}

class _OtpVerificationPageState extends State<OtpVerificationPage>
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  List<TextEditingController> _otpControllers = [];
  List<FocusNode> _focusNodes = [];
  final int _otpLength = 6;
  String _verificationId = '';
  int? _resendToken;
  final DatabaseService _databaseService = DatabaseService();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
      ),
    );

    _animationController.forward();

    // Initialize controllers and focus nodes
    for (int i = 0; i < _otpLength; i++) {
      _otpControllers.add(TextEditingController());
      _focusNodes.add(FocusNode());
    }

    // Start phone verification process
    _sendOtp();
  }

  @override
  void dispose() {
    // Dispose controllers and focus nodes
    for (int i = 0; i < _otpLength; i++) {
      _otpControllers[i].dispose();
      _focusNodes[i].dispose();
    }
    _animationController.dispose();
    super.dispose();
  }

  // In a real app, this would send an OTP to the user's phone
  // Here we're simulating it for development purposes
  Future<void> _sendOtp() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // For development mode, just simulate a delay
      await Future.delayed(const Duration(seconds: 1));
      setState(() {
        _verificationId = 'dev-mode-verification-id';
        _isLoading = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sending OTP: ${e.toString()}'),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _verifyOtp() async {
    // Get OTP from text fields
    String otp = '';
    for (int i = 0; i < _otpLength; i++) {
      otp += _otpControllers[i].text;
    }

    // Validate OTP length
    if (otp.length != _otpLength) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter all digits'),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // For development mode, simulate verification
      await Future.delayed(const Duration(milliseconds: 800));

      // Log this activity
      await _databaseService.logActivity(
        'User verified OTP: ${widget.email}',
        'Authentication',
      );

      // Navigate to home page
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Verification failed: ${e.toString()}'),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _proceedToHome() {
    setState(() {
      _isLoading = true;
    });

    // Simulate a brief loading state for UI feedback
    Future.delayed(const Duration(milliseconds: 500), () {
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
    });
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
          'Quick Access',
          style: TextStyle(
            color: AppTheme.primaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? screenSize.width * 0.2 : 24.0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              FadeTransition(
                opacity: _fadeAnimation,
                child: Center(
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryLightColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.speed,
                      size: 70,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  children: [
                    Text(
                      'Development Mode',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    AnimatedOpacity(
                      opacity: _animationController.value,
                      duration: const Duration(milliseconds: 300),
                      child: Text(
                        'Fast login enabled for ${widget.email}',
                        style: TextStyle(
                          fontSize: 16,
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),

              // OTP input fields (commented out for dev mode)
              // AnimatedOpacity(
              //   opacity: _animationController.value,
              //   duration: const Duration(milliseconds: 300),
              //   child: _buildOtpInputFields(),
              // ),
              // const SizedBox(height: 16),
              // Text(
              //   "Didn't receive the code?",
              //   style: TextStyle(color: AppTheme.textSecondary),
              //   textAlign: TextAlign.center,
              // ),
              // TextButton(
              //   onPressed: _isLoading ? null : _sendOtp,
              //   child: Text(
              //     'Resend Code',
              //     style: TextStyle(
              //       color: AppTheme.primaryColor,
              //       fontWeight: FontWeight.bold,
              //     ),
              //   ),
              // ),
              // const SizedBox(height: 24),

              // Primary button to proceed directly
              AnimatedOpacity(
                opacity: _animationController.value,
                duration: const Duration(milliseconds: 300),
                child: GradientButton(
                  text: 'Enter Application',
                  onPressed: _isLoading ? () {} : _proceedToHome,
                  colors: [AppTheme.primaryColor, AppTheme.primaryDarkColor],
                  height: 56,
                  width: double.infinity,
                  icon: _isLoading ? null : Icons.arrow_forward,
                ),
              ),

              if (_isLoading)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: AppTheme.primaryColor,
                        strokeWidth: 3,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 32),

              // Note about the development mode
              AnimatedOpacity(
                opacity: _animationController.value,
                duration: const Duration(milliseconds: 300),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.amber[50],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber[200]!),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.amber[800]),
                          const SizedBox(width: 8),
                          Text(
                            'Developer Note',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.amber[800],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'OTP verification has been disabled for faster testing. '
                        'This should be re-enabled before production.',
                        style: TextStyle(color: Colors.amber[800]),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper method to build OTP input fields
  Widget _buildOtpInputFields() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_otpLength, (index) {
        return Container(
          width: 50,
          height: 60,
          margin: const EdgeInsets.symmetric(horizontal: 5),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(
              color:
                  _focusNodes[index].hasFocus
                      ? AppTheme.primaryColor
                      : Colors.grey[300]!,
              width: _focusNodes[index].hasFocus ? 2 : 1,
            ),
          ),
          child: TextField(
            controller: _otpControllers[index],
            focusNode: _focusNodes[index],
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            maxLength: 1,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            decoration: const InputDecoration(
              counterText: '',
              border: InputBorder.none,
            ),
            onChanged: (value) {
              if (value.isNotEmpty && index < _otpLength - 1) {
                _focusNodes[index].unfocus();
                FocusScope.of(context).requestFocus(_focusNodes[index + 1]);
              }

              // Auto-verify if all fields are filled
              if (index == _otpLength - 1 && value.isNotEmpty) {
                // Check if all fields are filled
                bool allFilled = true;
                for (var controller in _otpControllers) {
                  if (controller.text.isEmpty) {
                    allFilled = false;
                    break;
                  }
                }

                if (allFilled) {
                  _verifyOtp();
                }
              }
            },
          ),
        );
      }),
    );
  }
}
