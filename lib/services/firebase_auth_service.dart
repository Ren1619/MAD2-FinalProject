import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:moneyger_finalproject/services/app_logger.dart';
import '../models/firebase_models.dart';
import '../utils/uuid_generator.dart';

class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AppLogger _logger = AppLogger();

  // Role constants
  static const String ROLE_ADMIN = 'Administrator';
  static const String ROLE_BUDGET_MANAGER = 'Budget Manager';
  static const String ROLE_FINANCIAL_OFFICER =
      'Financial Planning and Budgeting Officer';
  static const String ROLE_AUTHORIZED_SPENDER = 'Authorized Spender';

  // Get current Firebase user
  User? get currentFirebaseUser {
    return _auth.currentUser;
  }

  // Get current user data from Firestore
  Future<Map<String, dynamic>?> get currentUser async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final doc = await _firestore.collection('accounts').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        return {'account_id': doc.id, ...data};
      }
      return null;
    } catch (e) {
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
        final userData = await currentUser;
        if (userData != null) {
          // Check account status
          if (userData['status'] != 'Active') {
            await _logger.logLogin(email, success: false);
            return null;
          }

          // Log successful login
          await _logger.logLogin(email, success: true);

          // Update user context in logger
          await _logger.initialize();
          return userData;
        }
      }

      await _logger.logLogin(email, success: false);
      return null;
    } catch (e) {
      await _logger.logLogin(email, success: false);
      rethrow;
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
        final companyId = UuidGenerator.generateUuid();

        // Create company document
        await _firestore.collection('companies').doc(companyId).set({
          'company_id': companyId,
          'company_name': company.companyName,
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

        // Log company registration
        await _logger.logCompanyRegistration(company.companyName, adminEmail);

        return true;
      }
      return false;
    } catch (e) {
      // Cleanup if user was created but Firestore failed
      if (_auth.currentUser != null) {
        try {
          await _auth.currentUser!.delete();
        } catch (deleteError) {
          // Silent cleanup failure
        }
      }
      rethrow;
    }
  }

  // Create user account with auto re-authentication
  Future<bool> createUserAccountWithAutoReauth({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    required String role,
    String? phone,
    required String companyId,
    required String adminEmail,
    required String adminPassword,
  }) async {
    try {
      // Get current admin user data
      final currentUserData = await currentUser;
      if (currentUserData == null || currentUserData['role'] != ROLE_ADMIN) {
        await _logger.logUnauthorizedAccess(
          'create_account',
          currentUserData?['role'] ?? 'unknown',
        );
        throw 'Only administrators can create accounts';
      }

      // Validate role
      if (role == ROLE_ADMIN) {
        await _logger.logUnauthorizedAccess(
          'create_admin_account',
          currentUserData['role'],
        );
        throw 'Cannot create another administrator account';
      }

      // Create Firebase user
      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (result.user != null) {
        final newUserUid = result.user!.uid;

        // Create account document
        await _firestore.collection('accounts').doc(newUserUid).set({
          'account_id': newUserUid,
          'company_id': companyId,
          'f_name': firstName,
          'l_name': lastName,
          'email': email,
          'contact_number': phone ?? '',
          'role': role,
          'status': 'Active',
          'created_at': FieldValue.serverTimestamp(),
        });

        // Sign out new user
        await _auth.signOut();

        // Re-authenticate admin
        await _auth.signInWithEmailAndPassword(
          email: adminEmail,
          password: adminPassword,
        );

        // Log account creation
        await _logger.logAccountCreated(email, role, '$firstName $lastName');

        return true;
      }
      return false;
    } catch (e) {
      // Cleanup and re-auth logic
      try {
        final currentAuthUser = _auth.currentUser;
        if (currentAuthUser != null && currentAuthUser.email == email) {
          await currentAuthUser.delete();
        }

        // Try to re-authenticate admin
        if (adminEmail.isNotEmpty && adminPassword.isNotEmpty) {
          await _auth.signInWithEmailAndPassword(
            email: adminEmail,
            password: adminPassword,
          );
        }
      } catch (cleanupError) {
        // Silent cleanup failure
      }
      rethrow;
    }
  }

  // Keep the original method for backward compatibility
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
      // Get current admin user data before creating new account
      final currentUserData = await currentUser;
      if (currentUserData == null || currentUserData['role'] != ROLE_ADMIN) {
        await _logger.logUnauthorizedAccess(
          'create_account',
          currentUserData?['role'] ?? 'unknown',
        );
        throw 'Only administrators can create accounts';
      }

      // Store admin credentials for potential re-authentication
      final adminEmail = currentUserData['email'];

      // Validate role (admin cannot create another admin)
      if (role == ROLE_ADMIN) {
        await _logger.logUnauthorizedAccess(
          'create_admin_account',
          currentUserData['role'],
        );
        throw 'Cannot create another administrator account';
      }

      // Create Firebase user (this will sign out the current admin)
      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (result.user != null) {
        final newUserUid = result.user!.uid;

        // Create account document in Firestore for the new user
        await _firestore.collection('accounts').doc(newUserUid).set({
          'account_id': newUserUid,
          'company_id': companyId,
          'f_name': firstName,
          'l_name': lastName,
          'email': email,
          'contact_number': phone ?? '',
          'role': role,
          'status': 'Active',
          'created_at': FieldValue.serverTimestamp(),
        });

        // Sign out the newly created user
        await _auth.signOut();

        // Log account creation
        await _logger.logAccountCreated(email, role, '$firstName $lastName');

        return true;
      }
      throw 'Failed to create Firebase user account';
    } catch (e) {
      // Try to clean up if a user was created
      try {
        final currentAuthUser = _auth.currentUser;
        if (currentAuthUser != null && currentAuthUser.email == email) {
          await currentAuthUser.delete();
        }
      } catch (deleteError) {
        // Silent cleanup failure
      }
      rethrow;
    }
  }

  Future<bool> reAuthenticateAdmin(String email, String password) async {
    try {
      final UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      return result.user != null;
    } catch (e) {
      return false;
    }
  }

  // Method to check if current user is signed in
  bool get isSignedIn {
    return _auth.currentUser != null;
  }

  // Update user account status
  Future<bool> updateUserStatus(String accountId, String status) async {
    try {
      // Get account details before update
      final accountDoc =
          await _firestore.collection('accounts').doc(accountId).get();
      if (!accountDoc.exists) return false;

      final accountData = accountDoc.data()!;
      final oldStatus = accountData['status'];

      await _firestore.collection('accounts').doc(accountId).update({
        'status': status,
        'updated_at': FieldValue.serverTimestamp(),
      });

      // Log status change
      await _logger.logAccountStatusChanged(
        accountData['email'],
        '${accountData['f_name']} ${accountData['l_name']}',
        oldStatus,
        status,
      );

      return true;
    } catch (e) {
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
        await _logger.logUnauthorizedAccess(
          'delete_admin_account',
          accountData['role'],
        );
        throw 'Cannot delete administrator account';
      }

      // Delete from Firestore
      await _firestore.collection('accounts').doc(accountId).delete();

      // Log account deletion
      await _logger.logAccountDeleted(
        accountData['email'],
        '${accountData['f_name']} ${accountData['l_name']}',
      );

      return true;
    } catch (e) {
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
              .get();

      final accounts =
          snapshot.docs.map((doc) {
            final data = doc.data();
            return {'id': doc.id, ...data};
          }).toList();

      // Sort manually in Dart instead of Firestore
      accounts.sort((a, b) {
        final aTime = a['created_at'];
        final bTime = b['created_at'];

        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;

        try {
          DateTime dateA, dateB;
          dateA = aTime is Timestamp ? aTime.toDate() : DateTime.parse(aTime);
          dateB = bTime is Timestamp ? bTime.toDate() : DateTime.parse(bTime);
          return dateB.compareTo(dateA); // Descending order
        } catch (e) {
          return 0;
        }
      });

      return accounts;
    } catch (e) {
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

      // Log the action AFTER signout has completed
      if (userData != null) {
        await _logger.logLogout(userData['email']);
      }

      // Clear user context in logger
      _logger.clearUserContext();
    } catch (e) {
      rethrow;
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
      return false;
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      rethrow;
    }
  }

  // Update user profile
  Future<bool> updateUserProfile(
    String accountId,
    Map<String, dynamic> updates,
  ) async {
    try {
      // Get account details before update
      final accountDoc =
          await _firestore.collection('accounts').doc(accountId).get();
      if (!accountDoc.exists) return false;

      final accountData = accountDoc.data()!;

      await _firestore.collection('accounts').doc(accountId).update({
        ...updates,
        'updated_at': FieldValue.serverTimestamp(),
      });

      // Log profile update
      await _logger.logAccountUpdated(
        accountData['email'],
        '${accountData['f_name']} ${accountData['l_name']}',
        updates.keys.toList(),
      );

      return true;
    } catch (e) {
      return false;
    }
  }
}
