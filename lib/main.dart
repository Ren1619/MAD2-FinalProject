import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'login_page.dart';
import 'signup_page.dart';
import 'otp_verification_page.dart';
import 'role_based_router.dart';
import 'services/database_helper.dart';
import 'services/database_service.dart';
import 'services/auth_service.dart';
import 'utils/debug_data.dart';

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize database
  await DatabaseHelper().database;

  // Create auth service
  final AuthService authService = AuthService();

  // Create initial admin user if database is empty
  await authService.createInitialAdminIfNeeded();

  // Populate debug data if in development mode
  await DebugData.populateDebugData();

  runApp(
    // Provide DatabaseService at the root level
    ChangeNotifierProvider(
      create: (context) => DatabaseService(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Budget Management System',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Poppins',
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.blue[700]!, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
      // Use the role-based router as the initial screen
      home: const RoleBasedRouter(),
      routes: {
        '/login': (context) => const LoginPage(),
        '/signup': (context) => const SignupPage(),
        '/verify':
            (context) => const OtpVerificationPage(email: 'user@example.com'),
      },
    );
  }
}
