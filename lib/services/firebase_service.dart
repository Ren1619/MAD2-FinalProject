import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Auth reference
  User? get currentUser => _auth.currentUser;

  // Collection references
  CollectionReference get users => _firestore.collection('users');
  CollectionReference get budgets => _firestore.collection('budgets');
  CollectionReference get logs => _firestore.collection('logs');

  // Budget methods
  Future<List<Map<String, dynamic>>> fetchBudgets() async {
    try {
      QuerySnapshot snapshot =
          await budgets.orderBy('dateSubmitted', descending: true).get();
      return snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id; // Add document ID
        return data;
      }).toList();
    } catch (e) {
      print('Error fetching budgets: $e');
      return [];
    }
  }

  Future<void> createBudget(Map<String, dynamic> budgetData) async {
    try {
      await budgets.add({
        ...budgetData,
        'dateSubmitted': FieldValue.serverTimestamp(),
        'status': 'Pending',
        'submittedBy': currentUser?.uid,
        'submittedByEmail': currentUser?.email,
      });

      // Log this activity
      await logActivity(
        'New budget submitted: ${budgetData['name']}',
        'Budget',
      );
    } catch (e) {
      print('Error creating budget: $e');
      throw e;
    }
  }

  Future<void> updateBudgetStatus(
    String budgetId,
    String newStatus, {
    String? notes,
  }) async {
    try {
      Map<String, dynamic> updateData = {'status': newStatus};

      // Add appropriate timestamp field based on status
      if (newStatus == 'Approved') {
        updateData['dateApproved'] = FieldValue.serverTimestamp();
      } else if (newStatus == 'Denied') {
        updateData['dateDenied'] = FieldValue.serverTimestamp();
        if (notes != null) updateData['denialReason'] = notes;
      } else if (newStatus == 'For Revision') {
        updateData['revisionRequested'] = FieldValue.serverTimestamp();
        if (notes != null) updateData['revisionNotes'] = notes;
      } else if (newStatus == 'Archived') {
        updateData['dateArchived'] = FieldValue.serverTimestamp();
      }

      await budgets.doc(budgetId).update(updateData);

      // Log this activity
      String description = 'Budget status updated to $newStatus';
      await logActivity(description, 'Budget');
    } catch (e) {
      print('Error updating budget status: $e');
      throw e;
    }
  }

  // User account methods
  Future<List<Map<String, dynamic>>> fetchUsers() async {
    try {
      QuerySnapshot snapshot = await users.get();
      return snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('Error fetching users: $e');
      return [];
    }
  }

  Future<void> updateUserStatus(String userId, String newStatus) async {
    try {
      await users.doc(userId).update({'status': newStatus});

      // Log this activity
      String description = 'User status updated to $newStatus';
      await logActivity(description, 'Account Management');
    } catch (e) {
      print('Error updating user status: $e');
      throw e;
    }
  }

  // Logging methods
  Future<void> logActivity(String description, String type) async {
    try {
      await logs.add({
        'description': description,
        'timestamp': FieldValue.serverTimestamp(),
        'type': type,
        'user': currentUser?.email ?? 'System',
        'userId': currentUser?.uid,
        'ip':
            '192.168.1.1', // In a real app, you might get this from the device
      });
    } catch (e) {
      print('Error logging activity: $e');
    }
  }

  // Auth methods (from previous examples)
  Future<UserCredential> signInWithEmail(String email, String password) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> signOut() async {
    await logActivity('User signed out', 'Authentication');
    return _auth.signOut();
  }

  Future<UserCredential> createAccount(
    String email,
    String password,
    String name,
    String role,
  ) async {
    // Create the user account
    UserCredential credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    // Add user details to Firestore
    await users.doc(credential.user!.uid).set({
      'name': name,
      'email': email,
      'role': role,
      'status': 'Active',
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Log this activity
    await logActivity('New account created: $email', 'Account Management');

    return credential;
  }

  // Stream methods for real-time updates
  Stream<QuerySnapshot> budgetsStream() {
    return budgets.orderBy('dateSubmitted', descending: true).snapshots();
  }

  Stream<QuerySnapshot> usersStream() {
    return users.snapshots();
  }

  Stream<QuerySnapshot> logsStream() {
    return logs.orderBy('timestamp', descending: true).snapshots();
  }
}
