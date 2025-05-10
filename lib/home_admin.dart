import 'package:flutter/material.dart';
import 'accounts/accounts_page.dart';
import 'accounts/create_account_dialog.dart';
import 'budgets/budgets_page.dart';
import 'logs/logs_page.dart';
import 'widgets/sidebar_navigation.dart';
import 'login_page.dart';
import 'services/auth_service.dart';
import 'services/database_service.dart';
import 'package:provider/provider.dart';

class HomeAdminPage extends StatefulWidget {
  const HomeAdminPage({super.key});

  @override
  _HomeAdminPageState createState() => _HomeAdminPageState();
}

class _HomeAdminPageState extends State<HomeAdminPage> {
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final AuthService _authService = AuthService();
  late DatabaseService _databaseService;
  String _currentUserName = "Admin User";
  bool _isLoading = true;

  // List of page titles
  final List<String> _pageTitles = [
    'Manage Accounts',
    'Manage Budgets',
    'Activity Logs',
  ];

  @override
  void initState() {
    super.initState();
    // We'll initialize our DatabaseService in didChangeDependencies
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _databaseService = Provider.of<DatabaseService>(context);
    _loadUserInfo();
  }

  // Simplified to work without real authentication
  Future<void> _loadUserInfo() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get current user info (now mocked in the AuthService)
      final user = await _authService.currentUser;
      if (user != null) {
        setState(() {
          _currentUserName = user['name'] ?? "Admin User";
        });
      }
    } catch (e) {
      print('Error loading user info: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Handle logout
  void _handleLogout() async {
    try {
      await _authService.signOut();
      // Log activity
      await _databaseService.logActivity('User logged out', 'Authentication');
      // Navigate to login page
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error logging out: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          _pageTitles[_selectedIndex],
          style: TextStyle(
            color: Colors.blue[800],
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: IconThemeData(color: Colors.blue[800]),
        actions: [
          // Profile menu
          PopupMenuButton<String>(
            offset: const Offset(0, 45),
            icon: CircleAvatar(
              backgroundColor: Colors.blue[100],
              child: Icon(Icons.person, color: Colors.blue[800]),
            ),
            onSelected: (value) {
              switch (value) {
                case 'profile':
                  // Handle profile action
                  break;
                case 'settings':
                  // Handle settings action
                  break;
                case 'logout':
                  _handleLogout();
                  break;
              }
            },
            itemBuilder:
                (BuildContext context) => <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(
                    value: 'profile',
                    child: Row(
                      children: [
                        Icon(Icons.person, color: Colors.blue[800], size: 20),
                        const SizedBox(width: 10),
                        const Text('Profile'),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'settings',
                    child: Row(
                      children: [
                        Icon(Icons.settings, color: Colors.grey[700], size: 20),
                        const SizedBox(width: 10),
                        const Text('Settings'),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem<String>(
                    value: 'logout',
                    child: Row(
                      children: [
                        Icon(Icons.logout, color: Colors.red[400], size: 20),
                        const SizedBox(width: 10),
                        Text(
                          'Logout',
                          style: TextStyle(color: Colors.red[400]),
                        ),
                      ],
                    ),
                  ),
                ],
          ),
          const SizedBox(width: 16),
        ],
      ),
      drawer: SidebarNavigation(
        selectedIndex: _selectedIndex,
        onItemSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
      body:
          _isLoading
              ? Center(
                child: CircularProgressIndicator(color: Colors.blue[700]),
              )
              : _buildBody(),
      floatingActionButton:
          _selectedIndex == 0
              ? FloatingActionButton(
                backgroundColor: Colors.blue[700],
                child: const Icon(Icons.person_add),
                onPressed: () {
                  // Show create account dialog with refresh callback
                  showCreateAccountDialog(
                    context,
                    onAccountCreated: () {
                      // This will force a refresh using the database service notifier
                      _databaseService.notifyListeners();
                    },
                  );
                },
              )
              : null,
    );
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return const AccountsPage();
      case 1:
        return const BudgetsPage();
      case 2:
        return const LogsPage();
      default:
        return const AccountsPage();
    }
  }
}
