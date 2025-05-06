import 'package:flutter/material.dart';
import 'accounts/accounts_page.dart';
import 'accounts/create_account_dialog.dart';
import 'budgets/budgets_page.dart';
import 'logs/logs_page.dart';
import 'widgets/sidebar_navigation.dart';

class HomeAdminPage extends StatefulWidget {
  const HomeAdminPage({super.key});

  @override
  _HomeAdminPageState createState() => _HomeAdminPageState();
}

class _HomeAdminPageState extends State<HomeAdminPage> {
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // List of page titles
  final List<String> _pageTitles = [
    'Manage Accounts',
    'Manage Budgets',
    'Activity Logs',
  ];

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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: CircleAvatar(
              backgroundColor: Colors.blue[100],
              child: Icon(Icons.person, color: Colors.blue[800]),
            ),
          ),
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
      body: _buildBody(),
      floatingActionButton:
          _selectedIndex == 0
              ? FloatingActionButton(
                backgroundColor: Colors.blue[700],
                child: const Icon(Icons.person_add),
                onPressed: () {
                  // The create account dialog is now handled in the accounts page
                  if (_selectedIndex == 0) {
                    showCreateAccountDialog(context);
                  }
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
