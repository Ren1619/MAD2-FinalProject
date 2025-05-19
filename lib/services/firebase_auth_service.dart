import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/firebase_models.dart';
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
    if (user == null) {
      print('No Firebase user found');
      return null;
    }

    try {
      print('Getting user data for UID: ${user.uid}');
      final doc = await _firestore.collection('accounts').doc(user.uid).get();

      if (doc.exists) {
        final data = doc.data()!;
        print('User data found: $data');
        // Make sure to include the document ID as account_id
        return {'account_id': doc.id, ...data};
      } else {
        print('User document does not exist in Firestore');
        return null;
      }
    } catch (e) {
      print('Error getting current user data: $e');
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

        // Log activity
        await _logActivity(
          'New company registered: ${company.companyName} with admin: $adminEmail',
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

  // Modified: Create user account with auto re-authentication
  Future<bool> createUserAccountWithAutoReauth({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    required String role,
    String? phone,
    required String companyId,
    required String adminEmail,
    required String adminPassword, // Admin password for auto re-auth
  }) async {
    try {
      // Get current admin user data before creating new account
      final currentUserData = await currentUser;
      if (currentUserData == null || currentUserData['role'] != ROLE_ADMIN) {
        throw 'Only administrators can create accounts';
      }

      final adminUserId = currentUserData['account_id'];

      print('Admin creating account for: $email'); // Debug log

      // Validate role (admin cannot create another admin)
      if (role == ROLE_ADMIN) {
        throw 'Cannot create another administrator account';
      }

      print('Creating Firebase user for: $email'); // Debug log

      // Create Firebase user (this will sign out the current admin)
      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (result.user != null) {
        final newUserUid = result.user!.uid;
        print('Firebase user created with UID: $newUserUid'); // Debug log

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

        print('Account document created in Firestore'); // Debug log

        // Sign out the newly created user
        await _auth.signOut();
        print('New user signed out'); // Debug log

        // Automatically re-authenticate the admin
        print('Re-authenticating admin: $adminEmail'); // Debug log
        final adminReauth = await _auth.signInWithEmailAndPassword(
          email: adminEmail,
          password: adminPassword,
        );

        if (adminReauth.user != null) {
          print('Admin re-authenticated successfully'); // Debug log
        } else {
          print('Failed to re-authenticate admin'); // Debug log
          throw 'Failed to re-authenticate admin after account creation';
        }

        // Log activity directly to Firestore
        try {
          await _firestore.collection('logs').add({
            'log_id': UuidGenerator.generateUuid(),
            'log_desc':
                'New account created: $email with role: $role by admin: $adminEmail',
            'type': 'Account Management',
            'company_id': companyId,
            'user_id': adminUserId,
            'created_at': FieldValue.serverTimestamp(),
          });
          print('Activity logged successfully'); // Debug log
        } catch (logError) {
          print('Warning: Could not log activity: $logError');
        }

        return true;
      }

      throw 'Failed to create Firebase user account';
    } catch (e) {
      print('Error in createUserAccountWithAutoReauth: $e');

      // Try to clean up if a user was created
      try {
        final currentAuthUser = _auth.currentUser;
        if (currentAuthUser != null && currentAuthUser.email == email) {
          print('Cleaning up failed user account'); // Debug log
          await currentAuthUser.delete();
        }
      } catch (deleteError) {
        print('Warning: Could not delete failed user account: $deleteError');
      }

      // Try to re-authenticate admin even if account creation failed
      try {
        await _auth.signInWithEmailAndPassword(
          email: adminEmail,
          password: adminPassword,
        );
        print('Admin re-authenticated after error'); // Debug log
      } catch (reAuthError) {
        print('Failed to re-authenticate admin after error: $reAuthError');
      }

      rethrow; // Re-throw the original error
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
        throw 'Only administrators can create accounts';
      }

      // Store admin credentials for re-authentication
      final adminEmail = currentUserData['email'];
      final adminUserId = currentUserData['account_id'];

      print('Admin creating account for: $email'); // Debug log

      // Validate role (admin cannot create another admin)
      if (role == ROLE_ADMIN) {
        throw 'Cannot create another administrator account';
      }

      print('Creating Firebase user for: $email'); // Debug log

      // Create Firebase user (this will sign out the current admin)
      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (result.user != null) {
        final newUserUid = result.user!.uid;
        print('Firebase user created with UID: $newUserUid'); // Debug log

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

        print('Account document created in Firestore'); // Debug log

        // Sign out the newly created user
        await _auth.signOut();
        print('New user signed out'); // Debug log

        // Log activity directly to Firestore (no user needs to be signed in)
        try {
          await _firestore.collection('logs').add({
            'log_id': UuidGenerator.generateUuid(),
            'log_desc':
                'New account created: $email with role: $role by admin: $adminEmail',
            'type': 'Account Management',
            'company_id': companyId,
            'user_id': adminUserId,
            'created_at': FieldValue.serverTimestamp(),
          });
          print('Activity logged successfully'); // Debug log
        } catch (logError) {
          print('Warning: Could not log activity: $logError');
        }

        // Return true to indicate success
        // The UI will handle re-authentication if needed
        return true;
      }

      throw 'Failed to create Firebase user account';
    } catch (e) {
      print('Error in createUserAccount: $e');

      // Try to clean up if a user was created
      try {
        final currentAuthUser = _auth.currentUser;
        if (currentAuthUser != null && currentAuthUser.email == email) {
          print('Cleaning up failed user account'); // Debug log
          await currentAuthUser.delete();
        }
      } catch (deleteError) {
        print('Warning: Could not delete failed user account: $deleteError');
      }

      rethrow; // Re-throw the original error
    }
  }

  Future<bool> reAuthenticateAdmin(String email, String password) async {
    try {
      final UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (result.user != null) {
        print('Admin re-authenticated successfully');
        return true;
      }
      return false;
    } catch (e) {
      print('Error re-authenticating admin: $e');
      return false;
    }
  }

  // Method to check if current user is signed in
  bool get isSignedIn => _auth.currentUser != null;

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
      print('Fetching accounts for company: $companyId'); // Debug log

      // First, try without orderBy to see if it's an index issue
      final snapshot =
          await _firestore
              .collection('accounts')
              .where('company_id', isEqualTo: companyId)
              .get();

      print('Found ${snapshot.docs.length} accounts'); // Debug log

      final accounts =
          snapshot.docs.map((doc) {
            final data = doc.data();
            print('Account data: $data'); // Debug log
            return {'id': doc.id, ...data};
          }).toList();

      // Sort manually in Dart instead of Firestore
      accounts.sort((a, b) {
        final aTime = a['created_at'];
        final bTime = b['created_at'];

        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;

        // Handle both Timestamp and String
        DateTime dateA, dateB;
        try {
          dateA = aTime is Timestamp ? aTime.toDate() : DateTime.parse(aTime);
          dateB = bTime is Timestamp ? bTime.toDate() : DateTime.parse(bTime);
          return dateB.compareTo(dateA); // Descending order
        } catch (e) {
          print('Error parsing dates: $e');
          return 0;
        }
      });

      return accounts;
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
