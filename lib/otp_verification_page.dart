import 'package:flutter/material.dart';
import 'services/database_service.dart';

class OtpVerificationPage extends StatefulWidget {
  final String email;

  const OtpVerificationPage({super.key, required this.email});

  @override
  _OtpVerificationPageState createState() => _OtpVerificationPageState();
}

class _OtpVerificationPageState extends State<OtpVerificationPage> {
  bool _isLoading = false;
  List<TextEditingController> _otpControllers = [];
  List<FocusNode> _focusNodes = [];
  final int _otpLength = 6;
  String _verificationId = '';
  int? _resendToken;
  final DatabaseService _databaseService = DatabaseService();

  @override
  void initState() {
    super.initState();

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
        SnackBar(content: Text('Error sending OTP: ${e.toString()}')),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter all digits')));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // For development mode, simulate verification
      await Future.delayed(const Duration(milliseconds: 500));

      // Log this activity
      await _databaseService.logActivity(
        'User verified OTP: ${widget.email}',
        'Authentication',
      );

      // Navigate to home page
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Verification failed: ${e.toString()}')),
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.blue[700]),
        title: Text(
          'Quick Access',
          style: TextStyle(
            color: Colors.blue[800],
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              Icon(Icons.speed, size: 80, color: Colors.blue[700]),
              const SizedBox(height: 32),
              Text(
                'Development Mode',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[800],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Fast login enabled for ${widget.email}',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              // Primary button to proceed directly
              ElevatedButton(
                onPressed: _isLoading ? null : _proceedToHome,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 2,
                ),
                child:
                    _isLoading
                        ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.0,
                          ),
                        )
                        : const Text(
                          'Enter Application',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
              ),
              const SizedBox(height: 24),

              // Note about the development mode
              Container(
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
            ],
          ),
        ),
      ),
    );
  }
}
