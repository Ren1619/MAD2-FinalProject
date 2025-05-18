import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/company_model.dart';
import '../utils/uuid_generator.dart';

class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Role constants
  static const String ROLE_ADMIN = 'Administrator';
  static const String ROLE_BUDGET_MANAGER = 'Budget Manager';
  static const String ROLE_FINANCIAL_OFFICER =
      'Financial Planning and Budgeting Officer';
  static const String ROLE_AUTHORIZED_SPENDER = 'Authorized Spender';

  // Get current Firebase user
  User? get currentFirebaseUser => _auth.currentUser;

  // Get current user data from Firestore
  Future<Map<String, dynamic>?> get currentUser async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final doc = await _firestore.collection('accounts').doc(user.uid).get();
      if (doc.exists) {
        return {'id': doc.id, ...doc.data()!};
      }
      return null;
    } catch (e) {
      print('Error getting current user: $e');
      return null;
    }
  }

  // Sign in with email and password
  Future<Map<String, dynamic>?> signInWithEmail(
    String email,
    String password,
  ) async {
    try {
      final UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (result.user != null) {
        // Get user data from Firestore
        final userData = await currentUser;
        if (userData != null) {
          // Log activity
          await _logActivity(
            'User login: $email',
            'Authentication',
            userData['company_id'],
          );
          return userData;
        }
      }
      return null;
    } catch (e) {
      print('Error signing in: $e');
      throw e;
    }
  }

  // Register company with admin user
  Future<bool> registerCompanyWithAdmin({
    required Company company,
    required String adminName,
    required String adminEmail,
    required String adminPassword,
    String? adminPhone,
  }) async {
    try {
      // Check if company email already exists
      final existingCompany =
          await _firestore
              .collection('companies')
              .where('email', isEqualTo: company.email)
              .get();

      if (existingCompany.docs.isNotEmpty) {
        throw 'Company with this email already exists';
      }

      // Create Firebase user
      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: adminEmail,
        password: adminPassword,
      );

      if (result.user != null) {
        // Create company document
        final companyId = UuidGenerator.generateUuid();
        await _firestore.collection('companies').doc(companyId).set({
          'company_id': companyId,
          'company_name': company.name,
          'email': company.email,
          'phone': company.phone,
          'address': company.address,
          'city': company.city,
          'state': company.state,
          'zipcode': company.zipcode,
          'website': company.website,
          'size': company.size,
          'industry': company.industry,
          'created_at': FieldValue.serverTimestamp(),
        });

        // Create admin account document
        await _firestore.collection('accounts').doc(result.user!.uid).set({
          'account_id': result.user!.uid,
          'company_id': companyId,
          'f_name': adminName.split(' ')[0],
          'l_name':
              adminName.split(' ').length > 1 ? adminName.split(' ')[1] : '',
          'email': adminEmail,
          'contact_number': adminPhone ?? '',
          'role': ROLE_ADMIN,
          'status': 'Active',
          'created_at': FieldValue.serverTimestamp(),
        });

        // Log activity
        await _logActivity(
          'New company registered: ${company.name} with admin: $adminEmail',
          'Account Management',
          companyId,
        );

        return true;
      }
      return false;
    } catch (e) {
      print('Error registering company: $e');
      // If user was created but Firestore failed, delete the user
      if (_auth.currentUser != null) {
        await _auth.currentUser!.delete();
      }
      throw e;
    }
  }

  // Create user account (by admin)
  Future<bool> createUserAccount({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    required String role,
    String? phone,
    required String companyId,
  }) async {
    try {
      // Get current user to verify admin privileges
      final currentUserData = await currentUser;
      if (currentUserData == null || currentUserData['role'] != ROLE_ADMIN) {
        throw 'Only administrators can create accounts';
      }

      // Validate role (admin cannot create another admin)
      if (role == ROLE_ADMIN) {
        throw 'Cannot create another administrator account';
      }

      // Create Firebase user
      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (result.user != null) {
        // Create account document in Firestore
        await _firestore.collection('accounts').doc(result.user!.uid).set({
          'account_id': result.user!.uid,
          'company_id': companyId,
          'f_name': firstName,
          'l_name': lastName,
          'email': email,
          'contact_number': phone ?? '',
          'role': role,
          'status': 'Active',
          'created_at': FieldValue.serverTimestamp(),
        });

        // Log activity
        await _logActivity(
          'New account created: $email with role: $role',
          'Account Management',
          companyId,
        );

        return true;
      }
      return false;
    } catch (e) {
      print('Error creating user account: $e');
      // If user was created but Firestore failed, delete the user
      if (_auth.currentUser != null && _auth.currentUser!.email == email) {
        await _auth.currentUser!.delete();
      }
      throw e;
    }
  }

  // Update user account status
  Future<bool> updateUserStatus(String accountId, String status) async {
    try {
      await _firestore.collection('accounts').doc(accountId).update({
        'status': status,
        'updated_at': FieldValue.serverTimestamp(),
      });

      // Get account details for logging
      final accountDoc =
          await _firestore.collection('accounts').doc(accountId).get();
      if (accountDoc.exists) {
        final accountData = accountDoc.data()!;
        await _logActivity(
          'User status updated to $status: ${accountData['email']}',
          'Account Management',
          accountData['company_id'],
        );
      }

      return true;
    } catch (e) {
      print('Error updating user status: $e');
      return false;
    }
  }

  // Delete user account
  Future<bool> deleteUserAccount(String accountId) async {
    try {
      // Get account details before deletion
      final accountDoc =
          await _firestore.collection('accounts').doc(accountId).get();
      if (!accountDoc.exists) return false;

      final accountData = accountDoc.data()!;

      // Cannot delete admin account
      if (accountData['role'] == ROLE_ADMIN) {
        throw 'Cannot delete administrator account';
      }

      // Delete from Firestore
      await _firestore.collection('accounts').doc(accountId).delete();

      // Log activity
      await _logActivity(
        'Account deleted: ${accountData['email']}',
        'Account Management',
        accountData['company_id'],
      );

      return true;
    } catch (e) {
      print('Error deleting user account: $e');
      return false;
    }
  }

  // Get accounts by company
  Future<List<Map<String, dynamic>>> getAccountsByCompany(
    String companyId,
  ) async {
    try {
      final snapshot =
          await _firestore
              .collection('accounts')
              .where('company_id', isEqualTo: companyId)
              .orderBy('created_at', descending: true)
              .get();

      return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
    } catch (e) {
      print('Error getting accounts: $e');
      return [];
    }
  }

  // Get available roles for account creation
  static List<String> getAvailableRoles() {
    return [
      ROLE_BUDGET_MANAGER,
      ROLE_FINANCIAL_OFFICER,
      ROLE_AUTHORIZED_SPENDER,
    ];
  }

  // Sign out
  Future<void> signOut() async {
    try {
      final userData = await currentUser;
      await _auth.signOut();

      if (userData != null) {
        await _logActivity(
          'User signed out: ${userData['email']}',
          'Authentication',
          userData['company_id'],
        );
      }
    } catch (e) {
      print('Error signing out: $e');
    }
  }

  // Private helper method to log activities
  Future<void> _logActivity(
    String description,
    String type,
    String companyId,
  ) async {
    try {
      await _firestore.collection('logs').add({
        'log_id': UuidGenerator.generateUuid(),
        'log_desc': description,
        'type': type,
        'company_id': companyId,
        'created_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error logging activity: $e');
    }
  }

  // Check if user email exists
  Future<bool> checkEmailExists(String email) async {
    try {
      final snapshot =
          await _firestore
              .collection('accounts')
              .where('email', isEqualTo: email)
              .get();
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error checking email: $e');
      return false;
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      print('Error sending password reset email: $e');
      throw e;
    }
  }

  // Update user profile
  Future<bool> updateUserProfile(
    String accountId,
    Map<String, dynamic> updates,
  ) async {
    try {
      await _firestore.collection('accounts').doc(accountId).update({
        ...updates,
        'updated_at': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Error updating user profile: $e');
      return false;
    }
  }
}
