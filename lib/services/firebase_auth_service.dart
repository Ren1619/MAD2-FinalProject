import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:moneyger_finalproject/services/app_logger.dart';
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
  User? get currentFirebaseUser {
    final user = _auth.currentUser;
    logger.debug(
      'Getting current Firebase user',
      category: LogCategory.authentication,
      data: {'has_user': user != null, 'uid': user?.uid},
    );
    return user;
  }

  // Get current user data from Firestore
  Future<Map<String, dynamic>?> get currentUser async {
    return await logger.timeOperation('Get Current User Data', () async {
      final user = _auth.currentUser;
      if (user == null) {
        await logger.warning(
          'No Firebase user found when getting current user',
          category: LogCategory.authentication,
        );
        return null;
      }

      try {
        await logger.debug(
          'Fetching user data from Firestore',
          category: LogCategory.authentication,
          data: {'uid': user.uid},
        );

        final doc = await _firestore.collection('accounts').doc(user.uid).get();

        if (doc.exists) {
          final data = doc.data()!;
          final userData = {'account_id': doc.id, ...data};

          await logger.debug(
            'User data retrieved successfully',
            category: LogCategory.authentication,
            data: {
              'uid': user.uid,
              'email': userData['email'],
              'role': userData['role'],
              'status': userData['status'],
              'company_id': userData['company_id'],
            },
          );

          return userData;
        } else {
          await logger.error(
            'User document does not exist in Firestore',
            category: LogCategory.authentication,
            data: {'uid': user.uid, 'email': user.email},
          );
          return null;
        }
      } catch (e) {
        await logger.error(
          'Error getting current user data from Firestore',
          category: LogCategory.authentication,
          error: e,
          data: {'uid': user.uid, 'email': user.email},
        );
        return null;
      }
    }, data: {'operation': 'fetch_current_user'});
  }

  // Sign in with email and password
  Future<Map<String, dynamic>?> signInWithEmail(
    String email,
    String password,
  ) async {
    return await logger.timeOperation('User Sign In', () async {
      try {
        await logger.logAuthentication(
          'Sign in attempt',
          email: email,
          data: {'timestamp': DateTime.now().toIso8601String()},
        );

        final UserCredential result = await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );

        if (result.user != null) {
          await logger.info(
            'Firebase authentication successful',
            category: LogCategory.authentication,
            data: {
              'uid': result.user!.uid,
              'email': email,
              'email_verified': result.user!.emailVerified,
            },
          );

          final userData = await currentUser;
          if (userData != null) {
            // Check account status
            if (userData['status'] != 'Active') {
              await logger.logSecurity(
                'Inactive account login attempt',
                level: LogLevel.warning,
                data: {
                  'email': email,
                  'account_status': userData['status'],
                  'uid': result.user!.uid,
                  'company_id': userData['company_id'],
                },
              );

              await logger.logAuthentication(
                'Sign in denied - inactive account',
                success: false,
                email: email,
                data: {'account_status': userData['status']},
              );

              return null;
            }

            await logger.logAuthentication(
              'Sign in successful',
              email: email,
              data: {
                'user_role': userData['role'],
                'company_id': userData['company_id'],
                'account_status': userData['status'],
                'uid': result.user!.uid,
              },
            );

            // Update user context in logger
            await logger.initialize();

            return userData;
          } else {
            await logger.error(
              'User data not found in Firestore after successful Firebase auth',
              category: LogCategory.authentication,
              data: {'uid': result.user!.uid, 'email': email},
            );
          }
        }

        await logger.logAuthentication(
          'Sign in failed - Firebase auth returned null user',
          success: false,
          email: email,
        );
        return null;
      } catch (e) {
        await logger.error(
          'Sign in failed with exception',
          category: LogCategory.authentication,
          error: e,
          data: {'email': email, 'error_type': e.runtimeType.toString()},
        );
        rethrow;
      }
    }, data: {'email': email, 'operation': 'email_sign_in'});
  }

  // Register company with admin user
  Future<bool> registerCompanyWithAdmin({
    required Company company,
    required String adminName,
    required String adminEmail,
    required String adminPassword,
    String? adminPhone,
  }) async {
    return await logger.timeOperation(
      'Company Registration',
      () async {
        try {
          await logger.info(
            'Starting company registration process',
            category: LogCategory.accountManagement,
            data: {
              'company_name': company.companyName,
              'company_email': company.email,
              'admin_email': adminEmail,
              'admin_name': adminName,
              'has_phone': adminPhone?.isNotEmpty ?? false,
            },
          );

          // Check if company email already exists
          final existingCompany =
              await _firestore
                  .collection('companies')
                  .where('email', isEqualTo: company.email)
                  .get();

          if (existingCompany.docs.isNotEmpty) {
            await logger.logSecurity(
              'Company registration attempt with existing email',
              level: LogLevel.warning,
              data: {
                'company_email': company.email,
                'admin_email': adminEmail,
                'existing_company_id': existingCompany.docs.first.id,
              },
            );
            throw 'Company with this email already exists';
          }

          await logger.debug(
            'Company email validation passed',
            category: LogCategory.accountManagement,
            data: {'company_email': company.email},
          );

          // Create Firebase user
          await logger.debug(
            'Creating Firebase user for admin',
            category: LogCategory.authentication,
            data: {'admin_email': adminEmail},
          );

          final UserCredential result = await _auth
              .createUserWithEmailAndPassword(
                email: adminEmail,
                password: adminPassword,
              );

          if (result.user != null) {
            final companyId = UuidGenerator.generateUuid();

            await logger.debug(
              'Firebase user created, creating company document',
              category: LogCategory.accountManagement,
              data: {'company_id': companyId, 'admin_uid': result.user!.uid},
            );

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

            await logger.info(
              'Company document created successfully',
              category: LogCategory.accountManagement,
              data: {
                'company_id': companyId,
                'company_name': company.companyName,
              },
            );

            // Create admin account document
            await _firestore.collection('accounts').doc(result.user!.uid).set({
              'account_id': result.user!.uid,
              'company_id': companyId,
              'f_name': adminName.split(' ')[0],
              'l_name':
                  adminName.split(' ').length > 1
                      ? adminName.split(' ')[1]
                      : '',
              'email': adminEmail,
              'contact_number': adminPhone ?? '',
              'role': ROLE_ADMIN,
              'status': 'Active',
              'created_at': FieldValue.serverTimestamp(),
            });

            await logger.logAccountManagement(
              'Admin account created during company registration',
              targetEmail: adminEmail,
              data: {
                'company_id': companyId,
                'company_name': company.companyName,
                'admin_uid': result.user!.uid,
                'admin_role': ROLE_ADMIN,
              },
            );

            await logger.info(
              'Company registration completed successfully',
              category: LogCategory.accountManagement,
              data: {
                'company_id': companyId,
                'company_name': company.companyName,
                'admin_email': adminEmail,
                'admin_uid': result.user!.uid,
              },
            );

            return true;
          }

          await logger.error(
            'Company registration failed - Firebase user creation returned null',
            category: LogCategory.accountManagement,
            data: {'company_email': company.email, 'admin_email': adminEmail},
          );
          return false;
        } catch (e) {
          await logger.error(
            'Company registration failed with exception',
            category: LogCategory.accountManagement,
            error: e,
            data: {
              'company_name': company.companyName,
              'company_email': company.email,
              'admin_email': adminEmail,
            },
          );

          // Cleanup if user was created but Firestore failed
          if (_auth.currentUser != null) {
            try {
              await logger.warning(
                'Cleaning up failed company registration - deleting Firebase user',
                category: LogCategory.accountManagement,
                data: {'admin_uid': _auth.currentUser!.uid},
              );
              await _auth.currentUser!.delete();
            } catch (deleteError) {
              await logger.error(
                'Failed to cleanup Firebase user after registration failure',
                category: LogCategory.accountManagement,
                error: deleteError,
                data: {'admin_uid': _auth.currentUser!.uid},
              );
            }
          }
          rethrow;
        }
      },
      data: {
        'company_name': company.companyName,
        'admin_email': adminEmail,
        'operation': 'company_registration',
      },
    );
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
    return await logger.timeOperation(
      'Create User Account with Auto Reauth',
      () async {
        try {
          // Get current admin user data
          final currentUserData = await currentUser;
          if (currentUserData == null ||
              currentUserData['role'] != ROLE_ADMIN) {
            await logger.logSecurity(
              'Unauthorized account creation attempt',
              level: LogLevel.warning,
              data: {
                'attempted_by_email': currentUserData?['email'] ?? 'unknown',
                'attempted_by_role': currentUserData?['role'] ?? 'unknown',
                'target_email': email,
                'target_role': role,
              },
            );
            throw 'Only administrators can create accounts';
          }

          await logger.logAccountManagement(
            'Account creation started with auto reauth',
            targetEmail: email,
            data: {
              'target_role': role,
              'admin_email': adminEmail,
              'company_id': companyId,
              'has_phone': phone?.isNotEmpty ?? false,
            },
          );

          // Validate role
          if (role == ROLE_ADMIN) {
            await logger.logSecurity(
              'Attempt to create admin account blocked',
              level: LogLevel.warning,
              data: {
                'admin_email': adminEmail,
                'target_email': email,
                'company_id': companyId,
              },
            );
            throw 'Cannot create another administrator account';
          }

          await logger.debug(
            'Role validation passed, creating Firebase user',
            category: LogCategory.accountManagement,
            data: {'target_email': email, 'role': role},
          );

          // Create Firebase user
          final UserCredential result = await _auth
              .createUserWithEmailAndPassword(email: email, password: password);

          if (result.user != null) {
            final newUserUid = result.user!.uid;

            await logger.debug(
              'Firebase user created, creating Firestore document',
              category: LogCategory.accountManagement,
              data: {'new_user_uid': newUserUid, 'target_email': email},
            );

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

            await logger.debug(
              'Account document created, signing out new user',
              category: LogCategory.accountManagement,
              data: {'new_user_uid': newUserUid},
            );

            // Sign out new user
            await _auth.signOut();

            await logger.debug(
              'Re-authenticating admin user',
              category: LogCategory.authentication,
              data: {'admin_email': adminEmail},
            );

            // Re-authenticate admin
            await _auth.signInWithEmailAndPassword(
              email: adminEmail,
              password: adminPassword,
            );

            await logger.logAccountManagement(
              'Account created successfully with auto reauth',
              targetEmail: email,
              data: {
                'new_user_uid': newUserUid,
                'target_role': role,
                'company_id': companyId,
                'has_phone': phone?.isNotEmpty ?? false,
                'admin_reauthenticated': true,
              },
            );

            return true;
          }

          await logger.error(
            'Account creation failed - Firebase user not created',
            category: LogCategory.accountManagement,
            data: {
              'target_email': email,
              'role': role,
              'admin_email': adminEmail,
            },
          );
          return false;
        } catch (e) {
          await logger.error(
            'Account creation with auto reauth failed',
            category: LogCategory.accountManagement,
            error: e,
            data: {
              'target_email': email,
              'target_role': role,
              'admin_email': adminEmail,
              'company_id': companyId,
            },
          );

          // Cleanup and re-auth logic
          try {
            final currentAuthUser = _auth.currentUser;
            if (currentAuthUser != null && currentAuthUser.email == email) {
              await logger.warning(
                'Cleaning up failed user account',
                category: LogCategory.accountManagement,
                data: {'failed_user_uid': currentAuthUser.uid},
              );
              await currentAuthUser.delete();
            }

            // Try to re-authenticate admin
            if (adminEmail.isNotEmpty && adminPassword.isNotEmpty) {
              await logger.debug(
                'Attempting admin re-authentication after failure',
                category: LogCategory.authentication,
                data: {'admin_email': adminEmail},
              );
              await _auth.signInWithEmailAndPassword(
                email: adminEmail,
                password: adminPassword,
              );
            }
          } catch (cleanupError) {
            await logger.error(
              'Failed to cleanup after account creation failure',
              category: LogCategory.accountManagement,
              error: cleanupError,
              data: {'original_error': e.toString(), 'target_email': email},
            );
          }

          rethrow;
        }
      },
      data: {
        'target_email': email,
        'target_role': role,
        'admin_email': adminEmail,
        'operation': 'create_account_auto_reauth',
      },
    );
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
    return await logger.timeOperation(
      'Create User Account (Legacy)',
      () async {
        try {
          // Get current admin user data before creating new account
          final currentUserData = await currentUser;
          if (currentUserData == null ||
              currentUserData['role'] != ROLE_ADMIN) {
            await logger.logSecurity(
              'Unauthorized legacy account creation attempt',
              level: LogLevel.warning,
              data: {
                'attempted_by_email': currentUserData?['email'] ?? 'unknown',
                'attempted_by_role': currentUserData?['role'] ?? 'unknown',
                'target_email': email,
              },
            );
            throw 'Only administrators can create accounts';
          }

          // Store admin credentials for potential re-authentication
          final adminEmail = currentUserData['email'];
          final adminUserId = currentUserData['account_id'];

          await logger.logAccountManagement(
            'Legacy account creation started',
            targetEmail: email,
            data: {
              'target_role': role,
              'admin_email': adminEmail,
              'admin_user_id': adminUserId,
              'company_id': companyId,
            },
          );

          // Validate role (admin cannot create another admin)
          if (role == ROLE_ADMIN) {
            await logger.logSecurity(
              'Attempt to create admin account via legacy method blocked',
              level: LogLevel.warning,
              data: {'admin_email': adminEmail, 'target_email': email},
            );
            throw 'Cannot create another administrator account';
          }

          await logger.debug(
            'Creating Firebase user via legacy method',
            category: LogCategory.accountManagement,
            data: {'target_email': email},
          );

          // Create Firebase user (this will sign out the current admin)
          final UserCredential result = await _auth
              .createUserWithEmailAndPassword(email: email, password: password);

          if (result.user != null) {
            final newUserUid = result.user!.uid;

            await logger.debug(
              'Firebase user created via legacy method',
              category: LogCategory.accountManagement,
              data: {'new_user_uid': newUserUid},
            );

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

            await logger.debug(
              'Account document created via legacy method',
              category: LogCategory.accountManagement,
              data: {'new_user_uid': newUserUid},
            );

            // Sign out the newly created user
            await _auth.signOut();

            await logger.debug(
              'New user signed out, admin needs to re-authenticate',
              category: LogCategory.authentication,
            );

            // Log activity directly to Firestore (no user needs to be signed in)
            await logger.logAccountManagement(
              'Account created successfully via legacy method',
              targetEmail: email,
              data: {
                'new_user_uid': newUserUid,
                'target_role': role,
                'company_id': companyId,
                'admin_email': adminEmail,
                'admin_user_id': adminUserId,
                'method': 'legacy',
              },
            );

            return true;
          }

          await logger.error(
            'Legacy account creation failed - Firebase user not created',
            category: LogCategory.accountManagement,
            data: {
              'target_email': email,
              'role': role,
              'admin_email': adminEmail,
            },
          );
          throw 'Failed to create Firebase user account';
        } catch (e) {
          await logger.error(
            'Legacy account creation failed with exception',
            category: LogCategory.accountManagement,
            error: e,
            data: {
              'target_email': email,
              'target_role': role,
              'company_id': companyId,
            },
          );

          // Try to clean up if a user was created
          try {
            final currentAuthUser = _auth.currentUser;
            if (currentAuthUser != null && currentAuthUser.email == email) {
              await logger.warning(
                'Cleaning up failed legacy user account',
                category: LogCategory.accountManagement,
                data: {'failed_user_uid': currentAuthUser.uid},
              );
              await currentAuthUser.delete();
            }
          } catch (deleteError) {
            await logger.error(
              'Could not delete failed legacy user account',
              category: LogCategory.accountManagement,
              error: deleteError,
              data: {'target_email': email},
            );
          }

          rethrow;
        }
      },
      data: {
        'target_email': email,
        'target_role': role,
        'operation': 'create_account_legacy',
      },
    );
  }

  Future<bool> reAuthenticateAdmin(String email, String password) async {
    return await logger.timeOperation(
      'Admin Re-authentication',
      () async {
        try {
          await logger.debug(
            'Starting admin re-authentication',
            category: LogCategory.authentication,
            data: {'admin_email': email},
          );

          final UserCredential result = await _auth.signInWithEmailAndPassword(
            email: email,
            password: password,
          );

          if (result.user != null) {
            await logger.logAuthentication(
              'Admin re-authentication successful',
              email: email,
              data: {'uid': result.user!.uid},
            );
            return true;
          }

          await logger.logAuthentication(
            'Admin re-authentication failed - null user returned',
            success: false,
            email: email,
          );
          return false;
        } catch (e) {
          await logger.error(
            'Admin re-authentication failed with exception',
            category: LogCategory.authentication,
            error: e,
            data: {'admin_email': email},
          );
          return false;
        }
      },
      data: {'admin_email': email, 'operation': 'admin_reauth'},
    );
  }

  // Method to check if current user is signed in
  bool get isSignedIn {
    final signedIn = _auth.currentUser != null;
    logger.debug(
      'Checking sign-in status',
      category: LogCategory.authentication,
      data: {'is_signed_in': signedIn},
    );
    return signedIn;
  }

  // Update user account status
  Future<bool> updateUserStatus(String accountId, String status) async {
    return await logger.timeOperation(
      'Update User Status',
      () async {
        try {
          await logger.debug(
            'Starting user status update',
            category: LogCategory.accountManagement,
            data: {'target_account_id': accountId, 'new_status': status},
          );

          await _firestore.collection('accounts').doc(accountId).update({
            'status': status,
            'updated_at': FieldValue.serverTimestamp(),
          });

          // Get account details for logging
          final accountDoc =
              await _firestore.collection('accounts').doc(accountId).get();
          if (accountDoc.exists) {
            final accountData = accountDoc.data()!;

            await logger.logAccountManagement(
              'User status updated',
              targetEmail: accountData['email'],
              data: {
                'account_id': accountId,
                'old_status': accountData['status'],
                'new_status': status,
                'target_role': accountData['role'],
                'company_id': accountData['company_id'],
              },
            );
          } else {
            await logger.warning(
              'Account document not found after status update',
              category: LogCategory.accountManagement,
              data: {'account_id': accountId, 'new_status': status},
            );
          }

          return true;
        } catch (e) {
          await logger.error(
            'Failed to update user status',
            category: LogCategory.accountManagement,
            error: e,
            data: {'account_id': accountId, 'attempted_status': status},
          );
          return false;
        }
      },
      data: {
        'account_id': accountId,
        'new_status': status,
        'operation': 'update_user_status',
      },
    );
  }

  // Delete user account
  Future<bool> deleteUserAccount(String accountId) async {
    return await logger.timeOperation(
      'Delete User Account',
      () async {
        try {
          await logger.debug(
            'Starting user account deletion',
            category: LogCategory.accountManagement,
            data: {'target_account_id': accountId},
          );

          // Get account details before deletion
          final accountDoc =
              await _firestore.collection('accounts').doc(accountId).get();
          if (!accountDoc.exists) {
            await logger.warning(
              'Account deletion attempted on non-existent account',
              category: LogCategory.accountManagement,
              data: {'account_id': accountId},
            );
            return false;
          }

          final accountData = accountDoc.data()!;

          // Cannot delete admin account
          if (accountData['role'] == ROLE_ADMIN) {
            await logger.logSecurity(
              'Attempt to delete administrator account blocked',
              level: LogLevel.warning,
              data: {
                'account_id': accountId,
                'admin_email': accountData['email'],
                'company_id': accountData['company_id'],
              },
            );
            throw 'Cannot delete administrator account';
          }

          await logger.debug(
            'Account validation passed, proceeding with deletion',
            category: LogCategory.accountManagement,
            data: {
              'account_id': accountId,
              'target_email': accountData['email'],
              'target_role': accountData['role'],
            },
          );

          // Delete from Firestore
          await _firestore.collection('accounts').doc(accountId).delete();

          await logger.logAccountManagement(
            'Account deleted successfully',
            targetEmail: accountData['email'],
            data: {
              'deleted_account_id': accountId,
              'deleted_role': accountData['role'],
              'company_id': accountData['company_id'],
            },
          );

          return true;
        } catch (e) {
          await logger.error(
            'Failed to delete user account',
            category: LogCategory.accountManagement,
            error: e,
            data: {'account_id': accountId},
          );
          return false;
        }
      },
      data: {'account_id': accountId, 'operation': 'delete_user_account'},
    );
  }

  // Get accounts by company
  Future<List<Map<String, dynamic>>> getAccountsByCompany(
    String companyId,
  ) async {
    return await logger.timeOperation(
      'Fetch Company Accounts',
      () async {
        try {
          await logger.debug(
            'Fetching accounts for company',
            category: LogCategory.accountManagement,
            data: {'company_id': companyId},
          );

          final snapshot =
              await _firestore
                  .collection('accounts')
                  .where('company_id', isEqualTo: companyId)
                  .get();

          await logger.debug(
            'Accounts query completed',
            category: LogCategory.accountManagement,
            data: {
              'company_id': companyId,
              'accounts_found': snapshot.docs.length,
            },
          );

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
              dateA =
                  aTime is Timestamp ? aTime.toDate() : DateTime.parse(aTime);
              dateB =
                  bTime is Timestamp ? bTime.toDate() : DateTime.parse(bTime);
              return dateB.compareTo(dateA); // Descending order
            } catch (e) {
              logger.warning(
                'Error parsing account creation dates during sorting',
                category: LogCategory.accountManagement,
                data: {
                  'company_id': companyId,
                  'account_a_time': aTime?.toString(),
                  'account_b_time': bTime?.toString(),
                  'error': e.toString(),
                },
              );
              return 0;
            }
          });

          await logger.info(
            'Company accounts retrieved and sorted successfully',
            category: LogCategory.accountManagement,
            data: {
              'company_id': companyId,
              'total_accounts': accounts.length,
              'account_roles': accounts.map((a) => a['role']).toSet().toList(),
            },
          );

          return accounts;
        } catch (e) {
          await logger.error(
            'Failed to get company accounts',
            category: LogCategory.accountManagement,
            error: e,
            data: {'company_id': companyId},
          );
          return [];
        }
      },
      data: {'company_id': companyId, 'operation': 'get_company_accounts'},
    );
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

      await logger.debug(
        'Starting user sign out',
        category: LogCategory.authentication,
        data: {
          'user_email': userData?['email'],
          'user_role': userData?['role'],
        },
      );

      await _auth.signOut();

      // Log the action AFTER signout has completed
      if (userData != null) {
        await logger.logAuthentication(
          'User signed out successfully',
          email: userData['email'],
          data: {
            'user_role': userData['role'],
            'company_id': userData['company_id'],
          },
        );
      }

      // Clear user context in logger
      logger.clearUserContext();

      await logger.info(
        'Sign out completed successfully',
        category: LogCategory.authentication,
      );
    } catch (e) {
      await logger.error(
        'Error during sign out',
        category: LogCategory.authentication,
        error: e,
      );
      rethrow;
    }
  }

  // Check if user email exists
  Future<bool> checkEmailExists(String email) async {
    return await logger.timeOperation('Check Email Exists', () async {
      try {
        await logger.debug(
          'Checking if email exists',
          category: LogCategory.authentication,
          data: {'email': email},
        );

        final snapshot =
            await _firestore
                .collection('accounts')
                .where('email', isEqualTo: email)
                .get();

        final exists = snapshot.docs.isNotEmpty;

        await logger.debug(
          'Email existence check completed',
          category: LogCategory.authentication,
          data: {
            'email': email,
            'exists': exists,
            'found_accounts': snapshot.docs.length,
          },
        );

        return exists;
      } catch (e) {
        await logger.error(
          'Error checking email existence',
          category: LogCategory.authentication,
          error: e,
          data: {'email': email},
        );
        return false;
      }
    }, data: {'email': email, 'operation': 'check_email_exists'});
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await logger.info(
        'Sending password reset email',
        category: LogCategory.authentication,
        data: {'email': email},
      );

      await _auth.sendPasswordResetEmail(email: email);

      await logger.logAuthentication(
        'Password reset email sent',
        email: email,
        data: {'timestamp': DateTime.now().toIso8601String()},
      );
    } catch (e) {
      await logger.error(
        'Failed to send password reset email',
        category: LogCategory.authentication,
        error: e,
        data: {'email': email},
      );
      rethrow;
    }
  }

  // Update user profile
  Future<bool> updateUserProfile(
    String accountId,
    Map<String, dynamic> updates,
  ) async {
    return await logger.timeOperation(
      'Update User Profile',
      () async {
        try {
          await logger.debug(
            'Starting user profile update',
            category: LogCategory.accountManagement,
            data: {
              'account_id': accountId,
              'updated_fields': updates.keys.toList(),
            },
          );

          await _firestore.collection('accounts').doc(accountId).update({
            ...updates,
            'updated_at': FieldValue.serverTimestamp(),
          });

          // Get updated account details for logging
          final accountDoc =
              await _firestore.collection('accounts').doc(accountId).get();
          if (accountDoc.exists) {
            final accountData = accountDoc.data()!;

            await logger.logAccountManagement(
              'User profile updated',
              targetEmail: accountData['email'],
              data: {
                'account_id': accountId,
                'updated_fields': updates.keys.toList(),
                'user_role': accountData['role'],
                'company_id': accountData['company_id'],
              },
            );
          }

          return true;
        } catch (e) {
          await logger.error(
            'Failed to update user profile',
            category: LogCategory.accountManagement,
            error: e,
            data: {
              'account_id': accountId,
              'attempted_updates': updates.keys.toList(),
            },
          );
          return false;
        }
      },
      data: {
        'account_id': accountId,
        'operation': 'update_user_profile',
        'updated_fields_count': updates.length,
      },
    );
  }
}
