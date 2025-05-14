import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'login_page.dart';
import 'home_admin.dart';
import 'financial_planning/financial_planning_manager_home.dart';
import 'services/auth_service.dart';
import 'services/database_service.dart';

class RoleBasedRouter extends StatefulWidget {
  const RoleBasedRouter({super.key});

  @override
  _RoleBasedRouterState createState() => _RoleBasedRouterState();
}

class _RoleBasedRouterState extends State<RoleBasedRouter> {
  final AuthService _authService = AuthService();
  bool _isLoading = true;
  Map<String, dynamic>? _currentUser;

  @override
  void initState() {
    super.initState();
    _checkCurrentUser();
  }

  Future<void> _checkCurrentUser() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get current user
      _currentUser = await _authService.currentUser;
    } catch (e) {
      print('Error checking current user: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // If no user is logged in, show login page
    if (_currentUser == null) {
      return const LoginPage();
    }

    // Route based on user role
    final String role = _currentUser!['role'] ?? '';

    switch (role) {
      case 'Company Admin':
        return const HomeAdminPage();
      case 'Financial Planning and Analysis Manager':
        return const FinancialPlanningManagerHome();
      case 'Budget Manager':
        // TODO: Implement Budget Manager home page
        return const Scaffold(
          body: Center(
            child: Text('Budget Manager Dashboard - Coming Soon'),
          ),
        );
      case 'Authorized Spender':
        // TODO: Implement Authorized Spender home page
        return const Scaffold(
          body: Center(
            child: Text('Authorized Spender Dashboard - Coming Soon'),
          ),
        );
      default:
        // Default to login if role is not recognized
        return const LoginPage();
    }
  }
}