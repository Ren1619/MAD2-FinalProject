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
  int _selectedIndex = 0;
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  Map<String, int> _dashboardStats = {};

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadDashboardStats();
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

  Future<void> _loadDashboardStats() async {
    try {
      final authService = Provider.of<FirebaseAuthService>(
        context,
        listen: false,
      );
      final logsService = Provider.of<FirebaseLogsService>(
        context,
        listen: false,
      );

      if (_userData != null) {
        final companyId = _userData!['company_id'];

        // Get accounts count
        final accounts = await authService.getAccountsByCompany(companyId);

        // Get recent logs count
        final recentLogs = await logsService.getLogsForAdmin(limit: 10);

        // Get activity summary
        final activitySummary = await logsService.getActivitySummary();

        setState(() {
          _dashboardStats = {
            'accounts': accounts.length,
            'recentActivities': recentLogs.length,
            'totalActivities': activitySummary.values.fold(
              0,
              (sum, count) => sum + count,
            ),
          };
        });
      }
    } catch (e) {
      print('Error loading dashboard stats: $e');
    }
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

  Widget _buildMainContent() {
    switch (_selectedIndex) {
      case 0:
        return _buildDashboardHome();
      case 1:
        return const AccountsPage();
      case 2:
        return const BudgetsPage();
      case 3:
        return const LogsPage();
      default:
        return _buildDashboardHome();
    }
  }

  Widget _buildDashboardHome() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Section
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.primaryColor, AppTheme.primaryDarkColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome back, ${_userData?['f_name'] ?? 'Administrator'}!',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Manage your company\'s budget and financial operations',
                        style: TextStyle(
                          color: AppTheme.primaryLightColor,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.admin_panel_settings,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Stats Cards
          Text(
            'Overview',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),

          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.5,
            children: [
              _buildStatCard(
                'Total Accounts',
                '${_dashboardStats['accounts'] ?? 0}',
                Icons.people,
                Colors.blue,
                onTap: () => _onItemSelected(1), // Navigate to accounts
              ),
              _buildStatCard(
                'Recent Activities',
                '${_dashboardStats['recentActivities'] ?? 0}',
                Icons.history,
                Colors.green,
                onTap: () => _onItemSelected(3), // Navigate to logs
              ),
              _buildStatCard(
                'Total Activities',
                '${_dashboardStats['totalActivities'] ?? 0}',
                Icons.bar_chart,
                Colors.orange,
                onTap: () => _onItemSelected(3), // Navigate to logs
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Quick Actions
          Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _buildQuickActionCard(
                  'Manage Accounts',
                  'Create, edit, and manage user accounts',
                  Icons.group_add,
                  () => _onItemSelected(1),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildQuickActionCard(
                  'View Budgets',
                  'Monitor budget status and expenses',
                  Icons.account_balance_wallet,
                  () => _onItemSelected(2),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _buildQuickActionCard(
                  'Activity Logs',
                  'Review system activities and audit trail',
                  Icons.history,
                  () => _onItemSelected(3),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildQuickActionCard(
                  'Profile Settings',
                  'Update your profile information',
                  Icons.settings,
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ProfilePage(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color, {
    VoidCallback? onTap,
  }) {
    return HoverCard(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                if (onTap != null)
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: Colors.grey[400],
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionCard(
    String title,
    String description,
    IconData icon,
    VoidCallback onTap,
  ) {
    return HoverCard(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLightColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: AppTheme.primaryColor, size: 24),
                ),
                const Spacer(),
                Icon(Icons.arrow_forward, color: AppTheme.primaryColor),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      body: Row(
        children: [
          // Sidebar Navigation
          SidebarNavigation(
            selectedIndex: _selectedIndex,
            onItemSelected: _onItemSelected,
            userName:
                _userData != null
                    ? '${_userData!['f_name']} ${_userData!['l_name']}'
                    : null,
            userEmail: _userData?['email'],
            onLogout: _onLogout,
          ),

          // Main Content Area
          Expanded(child: _buildMainContent()),
        ],
      ),
    );
  }
}
