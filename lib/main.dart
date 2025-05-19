import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'login_page.dart';
import 'signup_page.dart';
import 'services/firebase_auth_service.dart';
import 'services/firebase_budget_service.dart';
import 'services/firebase_logs_service.dart';
import 'theme.dart';
import 'pages/admin_dashboard.dart';
import 'pages/budgets/budgets_page.dart'; // Import BudgetsPage

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Firebase Authentication Service
        Provider<FirebaseAuthService>(create: (_) => FirebaseAuthService()),
        // Firebase Budget Service
        Provider<FirebaseBudgetService>(create: (_) => FirebaseBudgetService()),
        // Firebase Logs Service
        Provider<FirebaseLogsService>(create: (_) => FirebaseLogsService()),
        // Application State Provider (for UI updates)
        ChangeNotifierProvider<AppStateNotifier>(
          create: (_) => AppStateNotifier(),
        ),
      ],
      child: MaterialApp(
        title: 'Budget Management System',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,

        // Use AuthWrapper to handle initial routing
        home: const AuthWrapper(),

        // Define named routes
        routes: {
          '/login': (context) => const LoginPage(),
          '/signup': (context) => const SignupPage(),
          '/admin-dashboard': (context) => const AdminDashboard(),
          '/budget-manager-dashboard':
              (context) => const BudgetManagerDashboard(),
          '/financial-officer-dashboard':
              (context) => const FinancialOfficerBudgetsPage(), // Updated route
          '/spender-dashboard': (context) => const AuthorizedSpenderDashboard(),
        },

        // Handle unknown routes
        onUnknownRoute: (settings) {
          return MaterialPageRoute(builder: (context) => const LoginPage());
        },
      ),
    );
  }
}

// App State Notifier for managing global state
class AppStateNotifier extends ChangeNotifier {
  bool _isLoading = false;
  String? _errorMessage;
  Map<String, dynamic>? _currentUser;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  Map<String, dynamic>? get currentUser => _currentUser;

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void setError(String? error) {
    _errorMessage = error;
    notifyListeners();
  }

  void setCurrentUser(Map<String, dynamic>? user) {
    _currentUser = user;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}

// Auth Wrapper to handle initial authentication state
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  Widget build(BuildContext context) {
    return Consumer<FirebaseAuthService>(
      builder: (context, authService, child) {
        return StreamBuilder(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, AsyncSnapshot<User?> snapshot) {
            // Show loading while checking auth state
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            // If user is not logged in, show login page
            if (snapshot.data == null) {
              return const LoginPage();
            }

            // If user is logged in, determine which dashboard to show
            return FutureBuilder<Map<String, dynamic>?>(
              future: authService.currentUser,
              builder: (context, userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }

                final userData = userSnapshot.data;
                if (userData == null) {
                  return const LoginPage();
                }

                // Update app state with current user
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  context.read<AppStateNotifier>().setCurrentUser(userData);
                });

                // Route to appropriate dashboard based on role
                switch (userData['role']) {
                  case FirebaseAuthService.ROLE_ADMIN:
                    return const AdminDashboard();
                  case FirebaseAuthService.ROLE_BUDGET_MANAGER:
                    return const BudgetManagerDashboard();
                  case FirebaseAuthService.ROLE_FINANCIAL_OFFICER:
                    // Route Financial Officers to the BudgetsPage
                    return FinancialOfficerBudgetsPage(userData: userData);
                  case FirebaseAuthService.ROLE_AUTHORIZED_SPENDER:
                    return const AuthorizedSpenderDashboard();
                  default:
                    return const LoginPage();
                }
              },
            );
          },
        );
      },
    );
  }
}

// Financial Officer Budgets Page Wrapper
class FinancialOfficerBudgetsPage extends StatelessWidget {
  final Map<String, dynamic>? userData;

  const FinancialOfficerBudgetsPage({super.key, this.userData});

  @override
  Widget build(BuildContext context) {
    // Use BudgetsPage as the main page for Financial Officers
    // No drawer needed since they only have access to budgets
    return BudgetsPage(
      userData: userData,
      // No onOpenDrawer since Financial Officers don't need a drawer
      // The BudgetsPage will automatically show the Create Budget button
      // for Financial Officers based on their role
    );
  }
}

// Keep the existing placeholder dashboards for other roles
class BudgetManagerDashboard extends StatelessWidget {
  const BudgetManagerDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Budget Manager Dashboard'),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: CircleAvatar(
              backgroundColor: Colors.blue[100],
              child: Icon(Icons.person, color: Colors.blue[800]),
            ),
            onSelected: (value) async {
              if (value == 'logout') {
                await context.read<FirebaseAuthService>().signOut();
              }
            },
            itemBuilder:
                (context) => [
                  const PopupMenuItem(
                    value: 'profile',
                    child: Row(
                      children: [
                        Icon(Icons.person),
                        SizedBox(width: 8),
                        Text('Profile'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'logout',
                    child: Row(
                      children: [
                        Icon(Icons.logout, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Logout', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
          ),
        ],
      ),
      body: const Center(
        child: Text(
          'Budget Manager Dashboard\n(To be implemented)',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}

class AuthorizedSpenderDashboard extends StatelessWidget {
  const AuthorizedSpenderDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Authorized Spender Dashboard'),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: CircleAvatar(
              backgroundColor: Colors.blue[100],
              child: Icon(Icons.person, color: Colors.blue[800]),
            ),
            onSelected: (value) async {
              if (value == 'logout') {
                await context.read<FirebaseAuthService>().signOut();
              }
            },
            itemBuilder:
                (context) => [
                  const PopupMenuItem(
                    value: 'profile',
                    child: Row(
                      children: [
                        Icon(Icons.person),
                        SizedBox(width: 8),
                        Text('Profile'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'logout',
                    child: Row(
                      children: [
                        Icon(Icons.logout, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Logout', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
          ),
        ],
      ),
      body: const Center(
        child: Text(
          'Authorized Spender Dashboard\n(To be implemented)',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
