import 'package:shared_preferences/shared_preferences.dart';
import '../utils/uuid_generator.dart';
import 'database_helper.dart';

class AuthService {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  
  // Current user information
  String? _currentUserId;
  Map<String, dynamic>? _currentUser;
  
  // Get current user
  Future<Map<String, dynamic>?> get currentUser async {
    if (_currentUser != null) {
      return _currentUser;
    }
    
    // Try to load from shared preferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString('userId');
    
    if (userId != null) {
      _currentUserId = userId;
      _currentUser = await _dbHelper.getUserById(userId);
    }
    
    return _currentUser;
  }
  
  // Sign in with email and password
  Future<bool> signInWithEmail(String email, String password) async {
    try {
      // In a real app, you would hash the password and compare with stored hash
      // For simplicity, we're just checking if the user exists with that email
      Map<String, dynamic>? user = await _dbHelper.getUserByEmail(email);
      
      if (user != null) {
        // Store user ID in shared preferences
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('userId', user['id']);
        
        // Update current user
        _currentUserId = user['id'];
        _currentUser = user;
        
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
  
  // Create a new user account
  Future<bool> createAccount(String email, String password, String name, String role) async {
    try {
      // Check if user with this email already exists
      Map<String, dynamic>? existingUser = await _dbHelper.getUserByEmail(email);
      
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
      
      // In a real app, you would hash the password before storing
      // For simplicity, we're not storing passwords in this example
      
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
      // Clear stored user ID
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove('userId');
      
      // Log activity if a user is currently signed in
      if (_currentUser != null) {
        await _dbHelper.insertLog({
          'id': UuidGenerator.generateUuid(),
          'description': 'User signed out: ${_currentUser!['email']}',
          'timestamp': DateTime.now().toIso8601String(),
          'type': 'Authentication',
          'user': _currentUser!['name'],
          'ip': '127.0.0.1',
        });
      }
      
      // Clear current user
      _currentUserId = null;
      _currentUser = null;
    } catch (e) {
      print('Error signing out: $e');
    }
  }
}