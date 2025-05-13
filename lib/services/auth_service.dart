import 'package:shared_preferences/shared_preferences.dart';
import '../utils/uuid_generator.dart';
import '../models/company_model.dart';
import 'database_helper.dart';

class AuthService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // Create an initial admin user if needed
  Future<void> createInitialAdminIfNeeded() async {
    final List<Map<String, dynamic>> existingUsers = await _dbHelper.getUsers();

    if (existingUsers.isEmpty) {
      // Create a default admin user
      String adminId = UuidGenerator.generateUuid();
      await _dbHelper.insertUser({
        'id': adminId,
        'name': 'Admin User',
        'email': 'admin@example.com',
        'role': 'Budget Manager',
        'status': 'Active',
        'createdAt': DateTime.now().toIso8601String(),
      });

      // Log admin creation
      await _dbHelper.insertLog({
        'id': UuidGenerator.generateUuid(),
        'description': 'System initialized with admin user',
        'timestamp': DateTime.now().toIso8601String(),
        'type': 'System',
        'user': 'System',
        'ip': '127.0.0.1',
      });
    }
  }

  // Get current user
  Future<Map<String, dynamic>?> get currentUser async {
    // For simplicity, we'll return the first active user in the database
    final List<Map<String, dynamic>> activeUsers = await _dbHelper
        .getUsersByStatus('Active');
    if (activeUsers.isNotEmpty) {
      return activeUsers.first;
    }
    return null;
  }

  // Sign in
  Future<bool> signInWithEmail(String email, String password) async {
    try {
      // Check if user exists and is active
      Map<String, dynamic>? user = await _dbHelper.getUserByEmail(email);

      if (user != null && user['status'] == 'Active') {
        // Log activity
        await _dbHelper.insertLog({
          'id': UuidGenerator.generateUuid(),
          'description': 'User login: $email',
          'timestamp': DateTime.now().toIso8601String(),
          'type': 'Authentication',
          'user': user['name'],
          'ip': '127.0.0.1',
        });

        return true;
      }
      return false;
    } catch (e) {
      print('Error signing in: $e');
      return false;
    }
  }

  // Register a new company and admin user
  Future<bool> registerCompanyAndAdmin({
    required Company company,
    required String adminName,
    required String adminEmail,
    required String adminPassword,
    required String adminRole,
    String? adminPhone,
    bool enableNotifications = true,
  }) async {
    try {
      // Check if admin email already exists
      Map<String, dynamic>? existingUser = await _dbHelper.getUserByEmail(
        adminEmail,
      );

      if (existingUser != null) {
        return false; // Admin email already exists
      }

      // Check if company email already exists
      Map<String, dynamic>? existingCompany = await _dbHelper.getCompanyByEmail(
        company.email,
      );

      if (existingCompany != null) {
        return false; // Company email already exists
      }

      // Insert company first
      Map<String, dynamic> companyMap = company.toMap();
      String companyId = await _dbHelper.insertCompany(companyMap);

      // Create admin user
      String adminId = UuidGenerator.generateUuid();
      Map<String, dynamic> adminUser = {
        'id': adminId,
        'name': adminName,
        'email': adminEmail,
        'role': adminRole,
        'status': 'Active',
        'createdAt': DateTime.now().toIso8601String(),
        'companyId': companyId,
        'phone': adminPhone ?? '',
        'enableNotifications': enableNotifications ? 1 : 0,
      };

      await _dbHelper.insertUser(adminUser);

      // Log activity
      await _dbHelper.insertLog({
        'id': UuidGenerator.generateUuid(),
        'description':
            'New company registered: ${company.name} with admin: $adminEmail',
        'timestamp': DateTime.now().toIso8601String(),
        'type': 'Account Management',
        'user': 'System',
        'ip': '127.0.0.1',
        'companyId': companyId,
      });

      return true;
    } catch (e) {
      print('Error registering company and admin: $e');
      return false;
    }
  }

  // Create a new user account
  Future<bool> createAccount(
    String email,
    String password,
    String name,
    String role,
  ) async {
    try {
      // Check if user with this email already exists
      Map<String, dynamic>? existingUser = await _dbHelper.getUserByEmail(
        email,
      );

      if (existingUser != null) {
        return false; // User already exists
      }

      // Create new user
      String id = UuidGenerator.generateUuid();
      Map<String, dynamic> newUser = {
        'id': id,
        'name': name,
        'email': email,
        'role': role,
        'status': 'Active',
        'createdAt': DateTime.now().toIso8601String(),
      };

      await _dbHelper.insertUser(newUser);

      // Log activity
      await _dbHelper.insertLog({
        'id': UuidGenerator.generateUuid(),
        'description': 'New account created: $email',
        'timestamp': DateTime.now().toIso8601String(),
        'type': 'Account Management',
        'user': 'System',
        'ip': '127.0.0.1',
      });

      return true;
    } catch (e) {
      print('Error creating account: $e');
      return false;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      // Get current user for logging
      Map<String, dynamic>? user = await currentUser;

      // Log activity
      await _dbHelper.insertLog({
        'id': UuidGenerator.generateUuid(),
        'description': 'User signed out: ${user?['email'] ?? 'Unknown'}',
        'timestamp': DateTime.now().toIso8601String(),
        'type': 'Authentication',
        'user': user?['name'] ?? 'Unknown',
        'ip': '127.0.0.1',
      });
    } catch (e) {
      print('Error signing out: $e');
    }
  }
}
