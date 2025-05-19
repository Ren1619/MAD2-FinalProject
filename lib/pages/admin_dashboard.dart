import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firebase_auth_service.dart';
import '../services/firebase_logs_service.dart';
import '../widgets/sidebar_navigation.dart';
import '../widgets/common_widgets.dart';
import '../theme.dart';
import 'accounts/accounts_page.dart';
import 'budgets/budgets_page.dart';
import 'logs/logs_page.dart';
import 'profile/profile_page.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedIndex = 0;
  Map<String, dynamic>? _userData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final authService = Provider.of<FirebaseAuthService>(
      context,
      listen: false,
    );
    final userData = await authService.currentUser;
    setState(() {
      _userData = userData;
      _isLoading = false;
    });
  }

  void _onItemSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _onLogout() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              'Confirm Logout',
              style: TextStyle(color: AppTheme.primaryColor),
            ),
            content: const Text('Are you sure you want to logout?'),
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
                  await Provider.of<FirebaseAuthService>(
                    context,
                    listen: false,
                  ).signOut();
                  Navigator.pushReplacementNamed(context, '/login');
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text(
                  'Logout',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }

  void _openDrawer() {
    print('Opening drawer from AdminDashboard');
    _scaffoldKey.currentState?.openDrawer();
  }

  Widget _buildMainContent() {
    switch (_selectedIndex) {
      case 0:
        return AccountsPageWithDrawer(
          onOpenDrawer: _openDrawer,
          userData: _userData,
        );
      case 1:
        return BudgetsPageWithDrawer(
          onOpenDrawer: _openDrawer,
          userData: _userData,
        );
      case 2:
        return LogsPageWithDrawer(
          onOpenDrawer: _openDrawer,
          userData: _userData,
        );
      default:
        return AccountsPageWithDrawer(
          onOpenDrawer: _openDrawer,
          userData: _userData,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppTheme.scaffoldBackground,
      drawer: SidebarNavigation(
        selectedIndex: _selectedIndex,
        onItemSelected: _onItemSelected,
        userName:
            _userData != null
                ? '${_userData!['f_name']} ${_userData!['l_name']}'
                : null,
        userEmail: _userData?['email'],
        onLogout: _onLogout,
      ),
      body: _buildMainContent(),
    );
  }
}

// PUT THE PAGE WRAPPERS HERE - Right after the AdminDashboard class

class AccountsPageWithDrawer extends StatelessWidget {
  final VoidCallback onOpenDrawer;
  final Map<String, dynamic>? userData;

  const AccountsPageWithDrawer({
    super.key,
    required this.onOpenDrawer,
    this.userData,
  });

  @override
  Widget build(BuildContext context) {
    // You'll need to modify AccountsPage to accept these parameters
    return AccountsPage(onOpenDrawer: onOpenDrawer, userData: userData);
  }
}

class BudgetsPageWithDrawer extends StatelessWidget {
  final VoidCallback onOpenDrawer;
  final Map<String, dynamic>? userData;

  const BudgetsPageWithDrawer({
    super.key,
    required this.onOpenDrawer,
    this.userData,
  });

  @override
  Widget build(BuildContext context) {
    // You'll need to modify BudgetsPage to accept these parameters
    return BudgetsPage(onOpenDrawer: onOpenDrawer, userData: userData);
  }
}

class LogsPageWithDrawer extends StatelessWidget {
  final VoidCallback onOpenDrawer;
  final Map<String, dynamic>? userData;

  const LogsPageWithDrawer({
    super.key,
    required this.onOpenDrawer,
    this.userData,
  });

  @override
  Widget build(BuildContext context) {
    // You'll need to modify LogsPage to accept these parameters
    return LogsPage(onOpenDrawer: onOpenDrawer, userData: userData);
  }
}
