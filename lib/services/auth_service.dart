import 'package:shared_preferences/shared_preferences.dart';
import '../utils/uuid_generator.dart';
import '../models/company_model.dart';
import 'database_helper.dart';

class AuthService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // Role constants
  static const String ROLE_COMPANY_ADMIN = 'Company Admin';
  static const String ROLE_BUDGET_MANAGER = 'Budget Manager';
  static const String ROLE_FINANCIAL_MANAGER =
      'Financial Planning and Analysis Manager';
  static const String ROLE_SPENDER = 'Authorized Spender';

  // List of available non-admin roles
  static List<String> getNonAdminRoles() {
    return [ROLE_BUDGET_MANAGER, ROLE_FINANCIAL_MANAGER, ROLE_SPENDER];
  }

  // Create an initial admin user if needed
  Future<void> createInitialAdminIfNeeded() async {
    final List<Map<String, dynamic>> existingUsers = await _dbHelper.getUsers();

    if (existingUsers.isEmpty) {
      // Create a default company first
      String companyId = UuidGenerator.generateUuid();
      await _dbHelper.insertCompany({
        'id': companyId,
        'name': 'Default Company',
        'email': 'admin@example.com',
        'phone': '+1 (555) 123-4567',
        'address': '123 Main Street',
        'city': 'San Francisco',
        'state': 'CA',
        'zipcode': '94105',
        'website': 'www.defaultcompany.com',
        'size': '1-10 employees',
        'industry': 'Information Technology',
        'createdAt': DateTime.now().toIso8601String(),
      });

      // Create a default admin user as Company Admin
      String adminId = UuidGenerator.generateUuid();
      await _dbHelper.insertUser({
        'id': adminId,
        'name': 'Admin User',
        'email': 'admin@example.com',
        'role': ROLE_COMPANY_ADMIN,
        'status': 'Active',
        'createdAt': DateTime.now().toIso8601String(),
        'companyId': companyId,
        'phone': '+1 (555) 123-4567',
        'enableNotifications': 1,
      });

      // Log admin creation
      await _dbHelper.insertLog({
        'id': UuidGenerator.generateUuid(),
        'description': 'System initialized with admin user',
        'timestamp': DateTime.now().toIso8601String(),
        'type': 'System',
        'user': 'System',
        'ip': '127.0.0.1',
        'companyId': companyId,
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

  // Register a new company with admin user
  Future<bool> registerCompanyWithAdmin({
    required Company company,
    required String adminName,
    required String adminEmail,
    required String adminPassword,
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

      // Convert Company object to Map
      Map<String, dynamic> companyMap = company.toMap();

      // Insert company first
      String companyId = await _dbHelper.insertCompany(companyMap);

      // Create admin user - always with Company Admin role
      String adminId = UuidGenerator.generateUuid();
      Map<String, dynamic> adminUser = {
        'id': adminId,
        'name': adminName,
        'email': adminEmail,
        'role': ROLE_COMPANY_ADMIN, // Fixed role for company registrant
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

  // Create a new user account (by admin)
  Future<bool> createUserAccount({
    required String name,
    required String email,
    required String password,
    required String role,
    String? phone,
    required String companyId,
    bool enableNotifications = true,
  }) async {
    try {
      // Check if user with this email already exists
      Map<String, dynamic>? existingUser = await _dbHelper.getUserByEmail(
        email,
      );

      if (existingUser != null) {
        return false; // User already exists
      }

      // Validate the role is not Company Admin (only one per company)
      if (role == ROLE_COMPANY_ADMIN) {
        // Check if company already has an admin
        List<Map<String, dynamic>> companyAdmins = await _dbHelper
            .getUsersByRoleAndCompany(ROLE_COMPANY_ADMIN, companyId);

        if (companyAdmins.isNotEmpty) {
          return false; // Company already has an admin
        }
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
        'companyId': companyId,
        'phone': phone ?? '',
        'enableNotifications': enableNotifications ? 1 : 0,
      };

      await _dbHelper.insertUser(newUser);

      // Get the admin user for logging
      Map<String, dynamic>? currentUser = await this.currentUser;
      String createdBy = currentUser != null ? currentUser['name'] : 'System';

      // Log activity
      await _dbHelper.insertLog({
        'id': UuidGenerator.generateUuid(),
        'description': 'New account created: $email with role: $role',
        'timestamp': DateTime.now().toIso8601String(),
        'type': 'Account Management',
        'user': createdBy,
        'ip': '127.0.0.1',
        'companyId': companyId,
      });

      return true;
    } catch (e) {
      print('Error creating user account: $e');
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
}
