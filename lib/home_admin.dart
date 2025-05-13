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
  String _currentUserEmail = "admin@example.com";
  bool _isLoading = true;

  // List of page titles
  final List<String> _pageTitles = [
    'Manage Accounts',
    'Manage Budgets',
    'Activity Logs',
    'Analytics',
  ];

  // Reference to the accounts page - we'll use a global key
  final GlobalKey<RefreshIndicatorState> _accountsRefreshKey =
      GlobalKey<RefreshIndicatorState>();

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

  Future<void> _loadUserInfo() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get current user info
      final user = await _authService.currentUser;
      if (user != null) {
        setState(() {
          _currentUserName = user['name'] ?? "Admin User";
          _currentUserEmail = user['email'] ?? "admin@example.com";
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
        userName: _currentUserName,
        userEmail: _currentUserEmail,
        onLogout: _handleLogout,
      ),
      body:
          _isLoading
              ? Center(
                child: CircularProgressIndicator(color: Colors.blue[700]),
              )
              : _buildBody(),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        // AccountsPage with refresh indicator key
        return AccountsPage();
      case 1:
        return const BudgetsPage();
      case 2:
        return const LogsPage();
      default:
        return AccountsPage();
    }
  }

  Widget? _buildFloatingActionButton() {
    // Show FAB on both dashboard and accounts pages (indices 0 and 1)
    if (_selectedIndex == 0 || _selectedIndex == 1) {
      // Accounts Page FAB
      return FloatingActionButton(
        backgroundColor: Colors.blue[700],
        child: const Icon(Icons.person_add),
        onPressed: () {
          showCreateAccountDialog(
            context,
            onAccountCreated: () {
              _databaseService.notifyListeners();
              if (_accountsRefreshKey.currentState != null) {
                _accountsRefreshKey.currentState!.show();
              }
            },
          );
        },
      );
    } else if (_selectedIndex == 2) {
      // Budget page's own FAB is handled by that page
      return null;
    } else {
      // No FAB for other pages
      return null;
    }
  }
}
