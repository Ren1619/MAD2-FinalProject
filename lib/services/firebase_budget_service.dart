import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:moneyger_finalproject/services/app_logger.dart';
import '../utils/uuid_generator.dart';
import '../utils/image_utils.dart';

class FirebaseBudgetService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AppLogger _logger = AppLogger();

  // Budget status constants
  static const String STATUS_PENDING = 'Pending for Approval';
  static const String STATUS_ACTIVE = 'Active';
  static const String STATUS_COMPLETED = 'Completed';
  static const String STATUS_FOR_REVISION = 'For Revision';

  // Get current user ID
  String? get _currentUserId {
    final userId = _auth.currentUser?.uid;
    _logger.debug(
      'Getting current user ID',
      category: LogCategory.authentication,
      data: {'has_user': userId != null, 'user_id': userId},
    );
    return userId;
  }

  // Create a new budget (Financial Officer only)
  Future<bool> createBudget({
    required String budgetName,
    required double budgetAmount,
    required String budgetDescription,
    required List<String> authorizedSpenderIds,
  }) async {
    return await _logger.timeOperation(
      'Create Budget',
      () async {
        try {
          if (_currentUserId == null) {
            await _logger.error(
              'Budget creation failed - no current user ID found',
              category: LogCategory.budgetManagement,
              data: {'budget_name': budgetName, 'budget_amount': budgetAmount},
            );
            return false;
          }

          await _logger.logBudgetManagement(
            'Budget creation started',
            budgetName: budgetName,
            amount: budgetAmount,
            data: {
              'authorized_spenders_count': authorizedSpenderIds.length,
              'description_length': budgetDescription.length,
            },
          );

          // Verify user is Financial Officer
          final userDoc =
              await _firestore.collection('accounts').doc(_currentUserId).get();
          if (!userDoc.exists) {
            await _logger.error(
              'Budget creation failed - user document not found',
              category: LogCategory.budgetManagement,
              data: {'user_id': _currentUserId, 'budget_name': budgetName},
            );
            return false;
          }

          final userData = userDoc.data()!;
          final userRole = userData['role'];

          if (userRole != 'Financial Planning and Budgeting Officer') {
            await _logger.logSecurity(
              'Unauthorized budget creation attempt',
              level: LogLevel.warning,
              data: {
                'user_id': _currentUserId,
                'user_role': userRole,
                'user_email': userData['email'],
                'budget_name': budgetName,
                'budget_amount': budgetAmount,
              },
            );
            throw 'Only Financial Planning and Budgeting Officers can create budgets';
          }

          final companyId = userData['company_id'];

          await _logger.debug(
            'User authorization verified for budget creation',
            category: LogCategory.budgetManagement,
            data: {
              'user_role': userRole,
              'company_id': companyId,
              'budget_name': budgetName,
            },
          );

          // Create budget document
          final budgetId = UuidGenerator.generateUuid();

          await _logger.debug(
            'Creating budget document',
            category: LogCategory.budgetManagement,
            data: {
              'budget_id': budgetId,
              'budget_name': budgetName,
              'status': STATUS_PENDING,
            },
          );

          await _firestore.collection('budgets').doc(budgetId).set({
            'budget_id': budgetId,
            'budget_name': budgetName,
            'budget_amount': budgetAmount,
            'budget_description': budgetDescription,
            'status': STATUS_PENDING,
            'created_by': _currentUserId,
            'company_id': companyId,
            'created_at': FieldValue.serverTimestamp(),
          });

          await _logger.debug(
            'Budget document created, adding authorized spenders',
            category: LogCategory.budgetManagement,
            data: {
              'budget_id': budgetId,
              'spenders_to_add': authorizedSpenderIds.length,
            },
          );

          // Create authorized spenders records
          int spendersAdded = 0;
          for (String spenderId in authorizedSpenderIds) {
            try {
              final authId = UuidGenerator.generateUuid();
              await _firestore
                  .collection('budgets_authorized_spenders')
                  .doc(authId)
                  .set({
                    'budget_auth_id': authId,
                    'budget_id': budgetId,
                    'account_id': spenderId,
                    'created_at': FieldValue.serverTimestamp(),
                  });
              spendersAdded++;
            } catch (e) {
              await _logger.error(
                'Failed to add authorized spender',
                category: LogCategory.budgetManagement,
                error: e,
                data: {'budget_id': budgetId, 'spender_id': spenderId},
              );
            }
          }

          await _logger.logBudgetManagement(
            'Budget created successfully',
            budgetId: budgetId,
            budgetName: budgetName,
            amount: budgetAmount,
            data: {
              'company_id': companyId,
              'status': STATUS_PENDING,
              'authorized_spenders_added': spendersAdded,
              'total_spenders_requested': authorizedSpenderIds.length,
              'created_by': _currentUserId,
            },
          );

          return true;
        } catch (e) {
          await _logger.error(
            'Budget creation failed with exception',
            category: LogCategory.budgetManagement,
            error: e,
            data: {
              'budget_name': budgetName,
              'budget_amount': budgetAmount,
              'authorized_spenders_count': authorizedSpenderIds.length,
            },
          );
          return false;
        }
      },
      data: {
        'budget_name': budgetName,
        'budget_amount': budgetAmount,
        'operation': 'create_budget',
      },
    );
  }

  // Get budgets by status for current user's role - FIXED VERSION
  Future<List<Map<String, dynamic>>> getBudgetsByStatus(String status) async {
    return await _logger.timeOperation(
      'Get Budgets by Status',
      () async {
        try {
          await _logger.debug(
            'Starting budget retrieval by status',
            category: LogCategory.budgetManagement,
            data: {
              'requested_status': status,
              'current_user_id': _currentUserId,
            },
          );

          if (_currentUserId == null) {
            await _logger.error(
              'Cannot get budgets - no current user ID found',
              category: LogCategory.budgetManagement,
              data: {'requested_status': status},
            );
            return [];
          }

          // Get current user data to determine role
          final userDoc =
              await _firestore.collection('accounts').doc(_currentUserId).get();
          if (!userDoc.exists) {
            await _logger.error(
              'Cannot get budgets - user document does not exist',
              category: LogCategory.budgetManagement,
              data: {'user_id': _currentUserId, 'requested_status': status},
            );
            return [];
          }

          final userData = userDoc.data()!;
          final userRole = userData['role'];
          final companyId = userData['company_id'];

          await _logger.debug(
            'User data retrieved for budget query',
            category: LogCategory.budgetManagement,
            data: {
              'user_role': userRole,
              'company_id': companyId,
              'requested_status': status,
            },
          );

          List<Map<String, dynamic>> budgets = [];

          switch (userRole) {
            case 'Administrator':
            case 'Budget Manager':
              await _logger.debug(
                'Fetching budgets for admin/budget manager',
                category: LogCategory.budgetManagement,
                data: {
                  'user_role': userRole,
                  'company_id': companyId,
                  'status': status,
                },
              );

              try {
                final snapshot =
                    await _firestore
                        .collection('budgets')
                        .where('company_id', isEqualTo: companyId)
                        .where('status', isEqualTo: status)
                        .get();

                await _logger.debug(
                  'Budget query completed successfully',
                  category: LogCategory.budgetManagement,
                  data: {
                    'budgets_found': snapshot.docs.length,
                    'query_type': 'direct',
                  },
                );

                budgets = await _processBudgetDocs(snapshot.docs);

                // Sort in dart instead of firestore
                budgets.sort((a, b) {
                  final aTime = a['created_at'] as Timestamp?;
                  final bTime = b['created_at'] as Timestamp?;
                  if (aTime == null || bTime == null) return 0;
                  return bTime.compareTo(aTime);
                });
              } catch (e) {
                await _logger.warning(
                  'Direct budget query failed, using fallback',
                  category: LogCategory.budgetManagement,
                  data: {
                    'error': e.toString(),
                    'fallback_strategy': 'filter_in_memory',
                  },
                );

                // Try fallback query without compound index
                final snapshot =
                    await _firestore
                        .collection('budgets')
                        .where('company_id', isEqualTo: companyId)
                        .get();

                await _logger.debug(
                  'Fallback query completed',
                  category: LogCategory.budgetManagement,
                  data: {
                    'total_budgets_found': snapshot.docs.length,
                    'will_filter_by_status': status,
                  },
                );

                final allBudgets = await _processBudgetDocs(snapshot.docs);
                budgets =
                    allBudgets
                        .where((budget) => budget['status'] == status)
                        .toList();

                // Sort in dart
                budgets.sort((a, b) {
                  final aTime = a['created_at'] as Timestamp?;
                  final bTime = b['created_at'] as Timestamp?;
                  if (aTime == null || bTime == null) return 0;
                  return bTime.compareTo(aTime);
                });
              }
              break;

            case 'Financial Planning and Budgeting Officer':
              await _logger.debug(
                'Fetching budgets for financial officer',
                category: LogCategory.budgetManagement,
                data: {'created_by': _currentUserId, 'status': status},
              );

              try {
                final snapshot =
                    await _firestore
                        .collection('budgets')
                        .where('created_by', isEqualTo: _currentUserId)
                        .where('status', isEqualTo: status)
                        .get();

                await _logger.debug(
                  'Financial officer budget query completed',
                  category: LogCategory.budgetManagement,
                  data: {
                    'budgets_found': snapshot.docs.length,
                    'query_type': 'direct',
                  },
                );

                budgets = await _processBudgetDocs(snapshot.docs);

                // Sort in dart
                budgets.sort((a, b) {
                  final aTime = a['created_at'] as Timestamp?;
                  final bTime = b['created_at'] as Timestamp?;
                  if (aTime == null || bTime == null) return 0;
                  return bTime.compareTo(aTime);
                });
              } catch (e) {
                await _logger.warning(
                  'Direct financial officer query failed, using fallback',
                  category: LogCategory.budgetManagement,
                  data: {
                    'error': e.toString(),
                    'fallback_strategy': 'filter_in_memory',
                  },
                );

                // Try fallback query
                final snapshot =
                    await _firestore
                        .collection('budgets')
                        .where('created_by', isEqualTo: _currentUserId)
                        .get();

                final allBudgets = await _processBudgetDocs(snapshot.docs);
                budgets =
                    allBudgets
                        .where((budget) => budget['status'] == status)
                        .toList();

                // Sort in dart
                budgets.sort((a, b) {
                  final aTime = a['created_at'] as Timestamp?;
                  final bTime = b['created_at'] as Timestamp?;
                  if (aTime == null || bTime == null) return 0;
                  return bTime.compareTo(aTime);
                });
              }
              break;

            case 'Authorized Spender':
              await _logger.debug(
                'Fetching budgets for authorized spender',
                category: LogCategory.budgetManagement,
                data: {'spender_id': _currentUserId, 'status': status},
              );
              budgets = await _getBudgetsForAuthorizedSpender(status);
              break;

            default:
              await _logger.logSecurity(
                'Unknown user role attempting to access budgets',
                level: LogLevel.warning,
                data: {
                  'user_id': _currentUserId,
                  'unknown_role': userRole,
                  'company_id': companyId,
                },
              );
              return [];
          }

          await _logger.info(
            'Budget retrieval completed successfully',
            category: LogCategory.budgetManagement,
            data: {
              'user_role': userRole,
              'requested_status': status,
              'budgets_returned': budgets.length,
              'company_id': companyId,
            },
          );

          return budgets;
        } catch (e) {
          await _logger.error(
            'Failed to get budgets by status',
            category: LogCategory.budgetManagement,
            error: e,
            data: {'requested_status': status, 'user_id': _currentUserId},
          );
          return [];
        }
      },
      data: {'requested_status': status, 'operation': 'get_budgets_by_status'},
    );
  }

  // Get budgets for authorized spender
  Future<List<Map<String, dynamic>>> _getBudgetsForAuthorizedSpender(
    String status,
  ) async {
    try {
      await _logger.debug(
        'Getting budgets for authorized spender',
        category: LogCategory.budgetManagement,
        data: {'spender_id': _currentUserId, 'status': status},
      );

      // Get all budget_auth records for this user
      final authSnapshot =
          await _firestore
              .collection('budgets_authorized_spenders')
              .where('account_id', isEqualTo: _currentUserId)
              .get();

      await _logger.debug(
        'Budget authorization records retrieved',
        category: LogCategory.budgetManagement,
        data: {
          'authorization_records_found': authSnapshot.docs.length,
          'spender_id': _currentUserId,
        },
      );

      if (authSnapshot.docs.isEmpty) {
        await _logger.info(
          'No budget authorizations found for spender',
          category: LogCategory.budgetManagement,
          data: {'spender_id': _currentUserId},
        );
        return [];
      }

      // Get budget IDs
      final budgetIds =
          authSnapshot.docs
              .map((doc) => doc.data()['budget_id'] as String)
              .toList();

      await _logger.debug(
        'Retrieved budget IDs for authorized spender',
        category: LogCategory.budgetManagement,
        data: {'budget_ids': budgetIds, 'spender_id': _currentUserId},
      );

      // Get budgets with the specified status
      List<Map<String, dynamic>> budgets = [];
      int processedBudgets = 0;
      int matchingBudgets = 0;

      for (String budgetId in budgetIds) {
        try {
          final budgetDoc =
              await _firestore.collection('budgets').doc(budgetId).get();
          processedBudgets++;

          if (budgetDoc.exists) {
            final budgetData = budgetDoc.data()!;

            await _logger.debug(
              'Processing budget for authorized spender',
              category: LogCategory.budgetManagement,
              data: {
                'budget_id': budgetId,
                'budget_status': budgetData['status'],
                'requested_status': status,
              },
            );

            if (budgetData['status'] == status) {
              final processedBudget = await _processBudgetDoc(budgetDoc);
              budgets.add(processedBudget);
              matchingBudgets++;
            }
          } else {
            await _logger.warning(
              'Budget document not found for authorized spender',
              category: LogCategory.budgetManagement,
              data: {'budget_id': budgetId, 'spender_id': _currentUserId},
            );
          }
        } catch (e) {
          await _logger.error(
            'Error processing budget for authorized spender',
            category: LogCategory.budgetManagement,
            error: e,
            data: {'budget_id': budgetId, 'spender_id': _currentUserId},
          );
        }
      }

      // Sort by created_at descending
      budgets.sort((a, b) {
        final aTime = a['created_at'] as Timestamp?;
        final bTime = b['created_at'] as Timestamp?;
        if (aTime == null || bTime == null) return 0;
        return bTime.compareTo(aTime);
      });

      await _logger.info(
        'Completed budget retrieval for authorized spender',
        category: LogCategory.budgetManagement,
        data: {
          'spender_id': _currentUserId,
          'requested_status': status,
          'total_authorizations': budgetIds.length,
          'processed_budgets': processedBudgets,
          'matching_budgets': matchingBudgets,
          'returned_budgets': budgets.length,
        },
      );

      return budgets;
    } catch (e) {
      await _logger.error(
        'Failed to get budgets for authorized spender',
        category: LogCategory.budgetManagement,
        error: e,
        data: {'spender_id': _currentUserId, 'status': status},
      );
      return [];
    }
  }

  // Process multiple budget documents
  Future<List<Map<String, dynamic>>> _processBudgetDocs(
    List<QueryDocumentSnapshot> docs,
  ) async {
    List<Map<String, dynamic>> budgets = [];
    int processedCount = 0;
    int errorCount = 0;

    await _logger.debug(
      'Starting to process budget documents',
      category: LogCategory.budgetManagement,
      data: {'total_docs': docs.length},
    );

    for (var doc in docs) {
      try {
        final budgetData = await _processBudgetDoc(doc);
        budgets.add(budgetData);
        processedCount++;
      } catch (e) {
        errorCount++;
        await _logger.error(
          'Error processing budget document',
          category: LogCategory.budgetManagement,
          error: e,
          data: {
            'document_id': doc.id,
            'budget_name': (doc.data() as Map<String, dynamic>?)?['budget_name'],
          },
        );
      }
    }

    await _logger.debug(
      'Completed processing budget documents',
      category: LogCategory.budgetManagement,
      data: {
        'total_docs': docs.length,
        'processed_successfully': processedCount,
        'errors': errorCount,
      },
    );

    return budgets;
  }

  // Process single budget document with additional data
  Future<Map<String, dynamic>> _processBudgetDoc(DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;

    try {
      await _logger.debug(
        'Processing single budget document',
        category: LogCategory.budgetManagement,
        data: {
          'budget_id': data['budget_id'],
          'budget_name': data['budget_name'],
        },
      );

      // Get creator information
      if (data['created_by'] != null) {
        try {
          final creatorDoc =
              await _firestore
                  .collection('accounts')
                  .doc(data['created_by'])
                  .get();
          if (creatorDoc.exists) {
            final creatorData = creatorDoc.data()!;
            data['created_by_name'] =
                '${creatorData['f_name']} ${creatorData['l_name']}';
            data['created_by_email'] = creatorData['email'];
          } else {
            await _logger.warning(
              'Creator document not found for budget',
              category: LogCategory.budgetManagement,
              data: {
                'budget_id': data['budget_id'],
                'created_by': data['created_by'],
              },
            );
            data['created_by_name'] = 'Unknown User';
          }
        } catch (e) {
          await _logger.error(
            'Error getting budget creator info',
            category: LogCategory.budgetManagement,
            error: e,
            data: {
              'budget_id': data['budget_id'],
              'created_by': data['created_by'],
            },
          );
          data['created_by_name'] = 'Unknown User';
        }
      }

      // Get authorized spenders
      try {
        final authSnapshot =
            await _firestore
                .collection('budgets_authorized_spenders')
                .where('budget_id', isEqualTo: data['budget_id'])
                .get();

        List<Map<String, dynamic>> authorizedSpenders = [];
        for (var authDoc in authSnapshot.docs) {
          try {
            final spenderDoc =
                await _firestore
                    .collection('accounts')
                    .doc(authDoc.data()['account_id'])
                    .get();
            if (spenderDoc.exists) {
              final spenderData = spenderDoc.data()!;
              authorizedSpenders.add({
                'account_id': spenderData['account_id'],
                'name': '${spenderData['f_name']} ${spenderData['l_name']}',
                'email': spenderData['email'],
              });
            }
          } catch (e) {
            await _logger.error(
              'Error getting spender info for budget',
              category: LogCategory.budgetManagement,
              error: e,
              data: {
                'budget_id': data['budget_id'],
                'spender_auth_id': authDoc.id,
              },
            );
          }
        }
        data['authorized_spenders'] = authorizedSpenders;

        await _logger.debug(
          'Retrieved authorized spenders for budget',
          category: LogCategory.budgetManagement,
          data: {
            'budget_id': data['budget_id'],
            'spenders_count': authorizedSpenders.length,
          },
        );
      } catch (e) {
        await _logger.error(
          'Error getting authorized spenders for budget',
          category: LogCategory.budgetManagement,
          error: e,
          data: {'budget_id': data['budget_id']},
        );
        data['authorized_spenders'] = [];
      }

      // Get expenses summary
      try {
        final expensesSnapshot =
            await _firestore
                .collection('expenses')
                .where('budget_id', isEqualTo: data['budget_id'])
                .get();

        double totalExpenses = 0;
        int expenseCount = expensesSnapshot.docs.length;

        for (var expenseDoc in expensesSnapshot.docs) {
          final expenseData = expenseDoc.data();
          totalExpenses += (expenseData['expense_amt'] as num).toDouble();
        }

        data['total_expenses'] = totalExpenses;
        data['expense_count'] = expenseCount;
        data['remaining_amount'] =
            (data['budget_amount'] as num).toDouble() - totalExpenses;

        await _logger.debug(
          'Retrieved expense summary for budget',
          category: LogCategory.budgetManagement,
          data: {
            'budget_id': data['budget_id'],
            'total_expenses': totalExpenses,
            'expense_count': expenseCount,
            'remaining_amount': data['remaining_amount'],
          },
        );
      } catch (e) {
        await _logger.error(
          'Error getting expenses summary for budget',
          category: LogCategory.budgetManagement,
          error: e,
          data: {'budget_id': data['budget_id']},
        );
        data['total_expenses'] = 0.0;
        data['expense_count'] = 0;
        data['remaining_amount'] = data['budget_amount'] ?? 0.0;
      }

      return data;
    } catch (e) {
      await _logger.error(
        'Error processing budget document',
        category: LogCategory.budgetManagement,
        error: e,
        data: {
          'budget_id': data['budget_id'],
          'budget_name': data['budget_name'],
        },
      );
      rethrow;
    }
  }

  // Update budget status (Budget Manager only)
  Future<bool> updateBudgetStatus(
    String budgetId,
    String newStatus, {
    String? notes,
  }) async {
    return await _logger.timeOperation(
      'Update Budget Status',
      () async {
        try {
          if (_currentUserId == null) {
            await _logger.error(
              'Budget status update failed - no current user ID',
              category: LogCategory.budgetManagement,
              data: {'budget_id': budgetId, 'new_status': newStatus},
            );
            return false;
          }

          await _logger.debug(
            'Starting budget status update',
            category: LogCategory.budgetManagement,
            data: {
              'budget_id': budgetId,
              'new_status': newStatus,
              'has_notes': notes != null,
              'user_id': _currentUserId,
            },
          );

          // Verify user is Budget Manager or Admin
          final userDoc =
              await _firestore.collection('accounts').doc(_currentUserId).get();
          if (!userDoc.exists) {
            await _logger.error(
              'Budget status update failed - user document not found',
              category: LogCategory.budgetManagement,
              data: {'user_id': _currentUserId, 'budget_id': budgetId},
            );
            return false;
          }

          final userRole = userDoc.data()!['role'];
          if (userRole != 'Budget Manager') {
            await _logger.logSecurity(
              'Unauthorized budget status update attempt',
              level: LogLevel.warning,
              data: {
                'user_id': _currentUserId,
                'user_role': userRole,
                'budget_id': budgetId,
                'attempted_status': newStatus,
              },
            );
            throw 'Only Budget Managers can update budget status';
          }

          await _logger.debug(
            'User authorization verified for budget status update',
            category: LogCategory.budgetManagement,
            data: {'user_role': userRole, 'budget_id': budgetId},
          );

          Map<String, dynamic> updateData = {
            'status': newStatus,
            'updated_at': FieldValue.serverTimestamp(),
            'updated_by': _currentUserId,
          };

          if (notes != null) {
            updateData['notes'] = notes;
          }

          await _firestore
              .collection('budgets')
              .doc(budgetId)
              .update(updateData);

          // Get budget details for logging
          final budgetDoc =
              await _firestore.collection('budgets').doc(budgetId).get();
          if (budgetDoc.exists) {
            final budgetData = budgetDoc.data()!;

            await _logger.logBudgetManagement(
              'Budget status updated',
              budgetId: budgetId,
              budgetName: budgetData['budget_name'],
              amount: budgetData['budget_amount'],
              data: {
                'old_status': budgetData['status'],
                'new_status': newStatus,
                'updated_by': _currentUserId,
                'has_notes': notes != null,
                'company_id': budgetData['company_id'],
              },
            );
          } else {
            await _logger.warning(
              'Budget document not found after status update',
              category: LogCategory.budgetManagement,
              data: {'budget_id': budgetId, 'new_status': newStatus},
            );
          }

          return true;
        } catch (e) {
          await _logger.error(
            'Budget status update failed with exception',
            category: LogCategory.budgetManagement,
            error: e,
            data: {
              'budget_id': budgetId,
              'attempted_status': newStatus,
              'user_id': _currentUserId,
            },
          );
          return false;
        }
      },
      data: {
        'budget_id': budgetId,
        'new_status': newStatus,
        'operation': 'update_budget_status',
      },
    );
  }

  // Create expense (Authorized Spender only)
  Future<bool> createExpense({
    required String budgetId,
    required String expenseDescription,
    required double expenseAmount,
    String? receiptBase64, // Base64 encoded receipt image
  }) async {
    return await _logger.timeOperation(
      'Create Expense',
      () async {
        try {
          if (_currentUserId == null) {
            await _logger.error(
              'Expense creation failed - no current user ID',
              category: LogCategory.expenseManagement,
              data: {'budget_id': budgetId, 'expense_amount': expenseAmount},
            );
            return false;
          }

          await _logger.logExpenseManagement(
            'Expense creation started',
            description: expenseDescription,
            amount: expenseAmount,
            data: {
              'budget_id': budgetId,
              'has_receipt': receiptBase64 != null,
              'user_id': _currentUserId,
            },
          );

          // Verify user is authorized spender for this budget
          final authSnapshot =
              await _firestore
                  .collection('budgets_authorized_spenders')
                  .where('budget_id', isEqualTo: budgetId)
                  .where('account_id', isEqualTo: _currentUserId)
                  .get();

          if (authSnapshot.docs.isEmpty) {
            await _logger.logSecurity(
              'Unauthorized expense creation attempt',
              level: LogLevel.warning,
              data: {
                'user_id': _currentUserId,
                'budget_id': budgetId,
                'expense_amount': expenseAmount,
                'expense_description': expenseDescription,
              },
            );
            throw 'You are not authorized to create expenses for this budget';
          }

          final budgetAuthId = authSnapshot.docs.first.data()['budget_auth_id'];

          await _logger.debug(
            'User authorization verified for expense creation',
            category: LogCategory.expenseManagement,
            data: {
              'budget_auth_id': budgetAuthId,
              'budget_id': budgetId,
              'user_id': _currentUserId,
            },
          );

          // Get budget info for company_id
          final budgetDoc =
              await _firestore.collection('budgets').doc(budgetId).get();
          if (!budgetDoc.exists) {
            await _logger.error(
              'Expense creation failed - budget not found',
              category: LogCategory.expenseManagement,
              data: {'budget_id': budgetId, 'user_id': _currentUserId},
            );
            throw 'Budget not found';
          }

          final budgetData = budgetDoc.data()!;
          final companyId = budgetData['company_id'];

          await _logger.debug(
            'Budget information retrieved for expense creation',
            category: LogCategory.expenseManagement,
            data: {
              'budget_id': budgetId,
              'budget_name': budgetData['budget_name'],
              'company_id': companyId,
            },
          );

          // Create expense document
          final expenseId = UuidGenerator.generateUuid();
          Map<String, dynamic> expenseData = {
            'expense_id': expenseId,
            'budget_auth_id': budgetAuthId,
            'budget_id': budgetId,
            'expense_desc': expenseDescription,
            'expense_amt': expenseAmount,
            'status': 'Pending',
            'created_by': _currentUserId,
            'company_id': companyId,
            'created_at': FieldValue.serverTimestamp(),
          };

          // Add receipt if provided
          if (receiptBase64 != null) {
            expenseData['receipt_image'] = receiptBase64;
            expenseData['has_receipt'] = true;

            await _logger.debug(
              'Receipt image attached to expense',
              category: LogCategory.expenseManagement,
              data: {
                'expense_id': expenseId,
                'receipt_size_chars': receiptBase64.length,
              },
            );
          } else {
            expenseData['has_receipt'] = false;
          }

          await _firestore
              .collection('expenses')
              .doc(expenseId)
              .set(expenseData);

          await _logger.logExpenseManagement(
            'Expense created successfully',
            expenseId: expenseId,
            description: expenseDescription,
            amount: expenseAmount,
            data: {
              'budget_id': budgetId,
              'budget_name': budgetData['budget_name'],
              'company_id': companyId,
              'has_receipt': receiptBase64 != null,
              'status': 'Pending',
              'created_by': _currentUserId,
            },
          );

          return true;
        } catch (e) {
          await _logger.error(
            'Expense creation failed with exception',
            category: LogCategory.expenseManagement,
            error: e,
            data: {
              'budget_id': budgetId,
              'expense_description': expenseDescription,
              'expense_amount': expenseAmount,
              'user_id': _currentUserId,
            },
          );
          return false;
        }
      },
      data: {
        'budget_id': budgetId,
        'expense_amount': expenseAmount,
        'operation': 'create_expense',
      },
    );
  }

  // Get expenses for a budget
  Future<List<Map<String, dynamic>>> getExpensesForBudget(
    String budgetId,
  ) async {
    return await _logger.timeOperation(
      'Get Expenses for Budget',
      () async {
        try {
          await _logger.debug(
            'Getting expenses for budget',
            category: LogCategory.expenseManagement,
            data: {'budget_id': budgetId},
          );

          final snapshot =
              await _firestore
                  .collection('expenses')
                  .where('budget_id', isEqualTo: budgetId)
                  .get();

          await _logger.debug(
            'Expense query completed',
            category: LogCategory.expenseManagement,
            data: {
              'budget_id': budgetId,
              'expenses_found': snapshot.docs.length,
            },
          );

          // Sort in dart instead of using orderBy
          final docs = snapshot.docs;
          docs.sort((a, b) {
            final aTime = a.data()['created_at'] as Timestamp?;
            final bTime = b.data()['created_at'] as Timestamp?;
            if (aTime == null || bTime == null) return 0;
            return bTime.compareTo(aTime);
          });

          List<Map<String, dynamic>> expenses = [];
          int processedCount = 0;
          int errorCount = 0;

          for (var doc in docs) {
            try {
              final data = doc.data();

              // Get creator information
              if (data['created_by'] != null) {
                try {
                  final creatorDoc =
                      await _firestore
                          .collection('accounts')
                          .doc(data['created_by'])
                          .get();
                  if (creatorDoc.exists) {
                    final creatorData = creatorDoc.data()!;
                    data['created_by_name'] =
                        '${creatorData['f_name']} ${creatorData['l_name']}';
                    data['created_by_email'] = creatorData['email'];
                  } else {
                    await _logger.warning(
                      'Creator document not found for expense',
                      category: LogCategory.expenseManagement,
                      data: {
                        'expense_id': data['expense_id'],
                        'created_by': data['created_by'],
                      },
                    );
                    data['created_by_name'] = 'Unknown User';
                  }
                } catch (e) {
                  await _logger.error(
                    'Error getting creator info for expense',
                    category: LogCategory.expenseManagement,
                    error: e,
                    data: {
                      'expense_id': data['expense_id'],
                      'created_by': data['created_by'],
                    },
                  );
                  data['created_by_name'] = 'Unknown User';
                }
              }

              expenses.add(data);
              processedCount++;
            } catch (e) {
              errorCount++;
              await _logger.error(
                'Error processing expense document',
                category: LogCategory.expenseManagement,
                error: e,
                data: {'document_id': doc.id, 'budget_id': budgetId},
              );
            }
          }

          await _logger.info(
            'Expense retrieval completed',
            category: LogCategory.expenseManagement,
            data: {
              'budget_id': budgetId,
              'total_expenses': snapshot.docs.length,
              'processed_successfully': processedCount,
              'errors': errorCount,
            },
          );

          return expenses;
        } catch (e) {
          await _logger.error(
            'Failed to get expenses for budget',
            category: LogCategory.expenseManagement,
            error: e,
            data: {'budget_id': budgetId},
          );
          return [];
        }
      },
      data: {'budget_id': budgetId, 'operation': 'get_expenses_for_budget'},
    );
  }

  // Update expense status (Budget Manager only)
  Future<bool> updateExpenseStatus(
    String expenseId,
    String newStatus, {
    String? notes,
  }) async {
    return await _logger.timeOperation(
      'Update Expense Status',
      () async {
        try {
          if (_currentUserId == null) {
            await _logger.error(
              'Expense status update failed - no current user ID',
              category: LogCategory.expenseManagement,
              data: {'expense_id': expenseId, 'new_status': newStatus},
            );
            return false;
          }

          await _logger.debug(
            'Starting expense status update',
            category: LogCategory.expenseManagement,
            data: {
              'expense_id': expenseId,
              'new_status': newStatus,
              'has_notes': notes != null,
              'user_id': _currentUserId,
            },
          );

          // Verify user is Budget Manager or Admin
          final userDoc =
              await _firestore.collection('accounts').doc(_currentUserId).get();
          if (!userDoc.exists) {
            await _logger.error(
              'Expense status update failed - user document not found',
              category: LogCategory.expenseManagement,
              data: {'user_id': _currentUserId, 'expense_id': expenseId},
            );
            return false;
          }

          final userRole = userDoc.data()!['role'];
          if (userRole != 'Budget Manager') {
            await _logger.logSecurity(
              'Unauthorized expense status update attempt',
              level: LogLevel.warning,
              data: {
                'user_id': _currentUserId,
                'user_role': userRole,
                'expense_id': expenseId,
                'attempted_status': newStatus,
              },
            );
            throw 'Only Budget Managers can update expense status';
          }

          await _logger.debug(
            'User authorization verified for expense status update',
            category: LogCategory.expenseManagement,
            data: {'user_role': userRole, 'expense_id': expenseId},
          );

          Map<String, dynamic> updateData = {
            'status': newStatus,
            'updated_at': FieldValue.serverTimestamp(),
            'updated_by': _currentUserId,
          };

          if (notes != null) {
            updateData['notes'] = notes;
          }

          await _firestore
              .collection('expenses')
              .doc(expenseId)
              .update(updateData);

          // Get expense details for logging
          final expenseDoc =
              await _firestore.collection('expenses').doc(expenseId).get();
          if (expenseDoc.exists) {
            final expenseData = expenseDoc.data()!;

            await _logger.logExpenseManagement(
              'Expense status updated',
              expenseId: expenseId,
              description: expenseData['expense_desc'],
              amount: expenseData['expense_amt'],
              data: {
                'old_status': expenseData['status'],
                'new_status': newStatus,
                'updated_by': _currentUserId,
                'has_notes': notes != null,
                'budget_id': expenseData['budget_id'],
                'company_id': expenseData['company_id'],
              },
            );
          } else {
            await _logger.warning(
              'Expense document not found after status update',
              category: LogCategory.expenseManagement,
              data: {'expense_id': expenseId, 'new_status': newStatus},
            );
          }

          return true;
        } catch (e) {
          await _logger.error(
            'Expense status update failed with exception',
            category: LogCategory.expenseManagement,
            error: e,
            data: {
              'expense_id': expenseId,
              'attempted_status': newStatus,
              'user_id': _currentUserId,
            },
          );
          return false;
        }
      },
      data: {
        'expense_id': expenseId,
        'new_status': newStatus,
        'operation': 'update_expense_status',
      },
    );
  }

  // Mark expense as fraudulent (Budget Manager only)
  Future<bool> markExpenseAsFraudulent(String expenseId, String reason) async {
    await _logger.logSecurity(
      'Expense marked as fraudulent',
      level: LogLevel.critical,
      data: {
        'expense_id': expenseId,
        'reason': reason,
        'marked_by': _currentUserId,
      },
    );

    return await updateExpenseStatus(expenseId, 'Fraudulent', notes: reason);
  }

  // Get available authorized spenders for current user's company
  Future<List<Map<String, dynamic>>> getAvailableAuthorizedSpenders() async {
    return await _logger.timeOperation(
      'Get Available Authorized Spenders',
      () async {
        try {
          if (_currentUserId == null) {
            await _logger.error(
              'Cannot get authorized spenders - no current user ID',
              category: LogCategory.budgetManagement,
            );
            return [];
          }

          await _logger.debug(
            'Getting available authorized spenders',
            category: LogCategory.budgetManagement,
            data: {'user_id': _currentUserId},
          );

          // Get current user's company
          final userDoc =
              await _firestore.collection('accounts').doc(_currentUserId).get();
          if (!userDoc.exists) {
            await _logger.error(
              'Cannot get authorized spenders - user document not found',
              category: LogCategory.budgetManagement,
              data: {'user_id': _currentUserId},
            );
            return [];
          }

          final companyId = userDoc.data()!['company_id'];

          await _logger.debug(
            'Querying authorized spenders for company',
            category: LogCategory.budgetManagement,
            data: {'company_id': companyId},
          );

          // Get all authorized spenders in the company
          final snapshot =
              await _firestore
                  .collection('accounts')
                  .where('company_id', isEqualTo: companyId)
                  .where('role', isEqualTo: 'Authorized Spender')
                  .where('status', isEqualTo: 'Active')
                  .get();

          final spenders =
              snapshot.docs.map((doc) {
                final data = doc.data();
                return {
                  'account_id': data['account_id'],
                  'name': '${data['f_name']} ${data['l_name']}',
                  'email': data['email'],
                  'contact_number': data['contact_number'] ?? '',
                };
              }).toList();

          await _logger.info(
            'Retrieved available authorized spenders',
            category: LogCategory.budgetManagement,
            data: {'company_id': companyId, 'spenders_found': spenders.length},
          );

          return spenders;
        } catch (e) {
          await _logger.error(
            'Failed to get available authorized spenders',
            category: LogCategory.budgetManagement,
            error: e,
            data: {'user_id': _currentUserId},
          );
          return [];
        }
      },
      data: {'operation': 'get_available_authorized_spenders'},
    );
  }

  // Get budget details by ID
  Future<Map<String, dynamic>?> getBudgetById(String budgetId) async {
    return await _logger.timeOperation(
      'Get Budget by ID',
      () async {
        try {
          await _logger.debug(
            'Getting budget by ID',
            category: LogCategory.budgetManagement,
            data: {'budget_id': budgetId},
          );

          final doc =
              await _firestore.collection('budgets').doc(budgetId).get();
          if (!doc.exists) {
            await _logger.warning(
              'Budget not found by ID',
              category: LogCategory.budgetManagement,
              data: {'budget_id': budgetId},
            );
            return null;
          }

          final budget = await _processBudgetDoc(doc);

          await _logger.info(
            'Budget retrieved successfully by ID',
            category: LogCategory.budgetManagement,
            data: {
              'budget_id': budgetId,
              'budget_name': budget['budget_name'],
              'status': budget['status'],
            },
          );

          return budget;
        } catch (e) {
          await _logger.error(
            'Failed to get budget by ID',
            category: LogCategory.budgetManagement,
            error: e,
            data: {'budget_id': budgetId},
          );
          return null;
        }
      },
      data: {'budget_id': budgetId, 'operation': 'get_budget_by_id'},
    );
  }

  // Get expense details by ID
  Future<Map<String, dynamic>?> getExpenseById(String expenseId) async {
    return await _logger.timeOperation(
      'Get Expense by ID',
      () async {
        try {
          await _logger.debug(
            'Getting expense by ID',
            category: LogCategory.expenseManagement,
            data: {'expense_id': expenseId},
          );

          final doc =
              await _firestore.collection('expenses').doc(expenseId).get();
          if (!doc.exists) {
            await _logger.warning(
              'Expense not found by ID',
              category: LogCategory.expenseManagement,
              data: {'expense_id': expenseId},
            );
            return null;
          }

          final data = doc.data()!;

          // Get creator information
          if (data['created_by'] != null) {
            try {
              final creatorDoc =
                  await _firestore
                      .collection('accounts')
                      .doc(data['created_by'])
                      .get();
              if (creatorDoc.exists) {
                final creatorData = creatorDoc.data()!;
                data['created_by_name'] =
                    '${creatorData['f_name']} ${creatorData['l_name']}';
                data['created_by_email'] = creatorData['email'];
              } else {
                data['created_by_name'] = 'Unknown User';
                await _logger.warning(
                  'Creator not found for expense',
                  category: LogCategory.expenseManagement,
                  data: {
                    'expense_id': expenseId,
                    'created_by': data['created_by'],
                  },
                );
              }
            } catch (e) {
              await _logger.error(
                'Error getting creator info for expense',
                category: LogCategory.expenseManagement,
                error: e,
                data: {
                  'expense_id': expenseId,
                  'created_by': data['created_by'],
                },
              );
              data['created_by_name'] = 'Unknown User';
            }
          }

          // Get budget information
          if (data['budget_id'] != null) {
            try {
              final budgetDoc =
                  await _firestore
                      .collection('budgets')
                      .doc(data['budget_id'])
                      .get();
              if (budgetDoc.exists) {
                final budgetData = budgetDoc.data()!;
                data['budget_name'] = budgetData['budget_name'];
              } else {
                await _logger.warning(
                  'Budget not found for expense',
                  category: LogCategory.expenseManagement,
                  data: {
                    'expense_id': expenseId,
                    'budget_id': data['budget_id'],
                  },
                );
              }
            } catch (e) {
              await _logger.error(
                'Error getting budget info for expense',
                category: LogCategory.expenseManagement,
                error: e,
                data: {'expense_id': expenseId, 'budget_id': data['budget_id']},
              );
            }
          }

          await _logger.info(
            'Expense retrieved successfully by ID',
            category: LogCategory.expenseManagement,
            data: {
              'expense_id': expenseId,
              'expense_description': data['expense_desc'],
              'amount': data['expense_amt'],
              'status': data['status'],
            },
          );

          return data;
        } catch (e) {
          await _logger.error(
            'Failed to get expense by ID',
            category: LogCategory.expenseManagement,
            error: e,
            data: {'expense_id': expenseId},
          );
          return null;
        }
      },
      data: {'expense_id': expenseId, 'operation': 'get_expense_by_id'},
    );
  }

  // Get pending approvals count for Budget Manager dashboard
  Future<int> getPendingApprovalsCount() async {
    return await _logger.timeOperation(
      'Get Pending Approvals Count',
      () async {
        try {
          if (_currentUserId == null) {
            await _logger.error(
              'Cannot get pending approvals - no current user ID',
              category: LogCategory.budgetManagement,
            );
            return 0;
          }

          await _logger.debug(
            'Getting pending approvals count',
            category: LogCategory.budgetManagement,
            data: {'user_id': _currentUserId},
          );

          final userDoc =
              await _firestore.collection('accounts').doc(_currentUserId).get();
          if (!userDoc.exists) {
            await _logger.error(
              'Cannot get pending approvals - user document not found',
              category: LogCategory.budgetManagement,
              data: {'user_id': _currentUserId},
            );
            return 0;
          }

          final companyId = userDoc.data()!['company_id'];

          // Count pending budgets
          final budgetsSnapshot =
              await _firestore
                  .collection('budgets')
                  .where('company_id', isEqualTo: companyId)
                  .where('status', isEqualTo: STATUS_PENDING)
                  .get();

          // Count pending expenses
          final expensesSnapshot =
              await _firestore
                  .collection('expenses')
                  .where('company_id', isEqualTo: companyId)
                  .where('status', isEqualTo: 'Pending')
                  .get();

          final totalPending =
              budgetsSnapshot.docs.length + expensesSnapshot.docs.length;

          await _logger.info(
            'Retrieved pending approvals count',
            category: LogCategory.budgetManagement,
            data: {
              'company_id': companyId,
              'pending_budgets': budgetsSnapshot.docs.length,
              'pending_expenses': expensesSnapshot.docs.length,
              'total_pending': totalPending,
            },
          );

          return totalPending;
        } catch (e) {
          await _logger.error(
            'Failed to get pending approvals count',
            category: LogCategory.budgetManagement,
            error: e,
            data: {'user_id': _currentUserId},
          );
          return 0;
        }
      },
      data: {'operation': 'get_pending_approvals_count'},
    );
  }

  // Test method to check if we can connect to Firestore and get budgets
  Future<List<Map<String, dynamic>>> testGetBudgets() async {
    return await _logger.timeOperation('Test Get Budgets', () async {
      try {
        await _logger.info(
          'Starting Firestore connection test',
          category: LogCategory.system,
        );

        // Get all budgets without any filtering
        final snapshot = await _firestore.collection('budgets').get();

        await _logger.info(
          'Firestore connection test successful',
          category: LogCategory.system,
          data: {'total_budgets_in_collection': snapshot.docs.length},
        );

        List<Map<String, dynamic>> budgets = [];
        for (var doc in snapshot.docs) {
          final data = doc.data();

          await _logger.debug(
            'Test - Processing budget document',
            category: LogCategory.budgetManagement,
            data: {
              'budget_name': data['budget_name'],
              'status': data['status'],
              'company_id': data['company_id'],
            },
          );

          budgets.add(data);
        }

        await _logger.info(
          'Firestore test completed successfully',
          category: LogCategory.system,
          data: {
            'budgets_processed': budgets.length,
            'connection_status': 'successful',
          },
        );

        return budgets;
      } catch (e) {
        await _logger.error(
          'Firestore connection test failed',
          category: LogCategory.system,
          error: e,
        );
        return [];
      }
    }, data: {'operation': 'test_firestore_connection'});
  }
}
