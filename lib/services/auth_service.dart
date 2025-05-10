import 'package:shared_preferences/shared_preferences.dart';
import '../utils/uuid_generator.dart';
import 'database_helper.dart';

class AuthService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // Mock user information for development
  final Map<String, dynamic> _mockUser = {
    'id': 'admin-user-id',
    'name': 'Admin User',
    'email': 'admin@example.com',
    'role': 'Budget Manager',
    'status': 'Active',
    'createdAt': '2024-01-01T00:00:00.000Z',
  };

  // Get current user (bypassing real authentication)
  Future<Map<String, dynamic>?> get currentUser async {
    // Always return the mock user for development
    return _mockUser;
  }

  // Mock sign in (always returns success)
  Future<bool> signInWithEmail(String email, String password) async {
    try {
      // For development, always return successful login
      // Log activity
      await _dbHelper.insertLog({
        'id': UuidGenerator.generateUuid(),
        'description': 'User login: $email',
        'timestamp': DateTime.now().toIso8601String(),
        'type': 'Authentication',
        'user': _mockUser['name'],
        'ip': '127.0.0.1',
      });

      return true;
    } catch (e) {
      print('Error signing in: $e');
      return false;
    }
  }

  // Create a new user account (simplified)
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

  // Sign out (simplified)
  Future<void> signOut() async {
    try {
      // Log activity
      await _dbHelper.insertLog({
        'id': UuidGenerator.generateUuid(),
        'description': 'User signed out: ${_mockUser['email']}',
        'timestamp': DateTime.now().toIso8601String(),
        'type': 'Authentication',
        'user': _mockUser['name'],
        'ip': '127.0.0.1',
      });
    } catch (e) {
      print('Error signing out: $e');
    }
  }
}
