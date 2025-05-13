import 'dart:async';
import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../utils/uuid_generator.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, 'moneyger.db');

    var db = await openDatabase(path, version: 1, onCreate: _createDb);
    return db;
  }

  Future<void> _createDb(Database db, int version) async {
    // Create users table with indexes
    await db.execute('''
    CREATE TABLE users(
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      email TEXT NOT NULL,
      role TEXT NOT NULL,
      status TEXT NOT NULL,
      createdAt TEXT NOT NULL
    )
  ''');

    // Add indexes for frequently queried fields
    await db.execute('CREATE INDEX idx_users_email ON users(email)');
    await db.execute('CREATE INDEX idx_users_status ON users(status)');
    await db.execute('CREATE INDEX idx_users_role ON users(role)');

    // Create budgets table with indexes
    await db.execute('''
    CREATE TABLE budgets(
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      budget REAL NOT NULL,
      description TEXT NOT NULL,
      status TEXT NOT NULL,
      dateSubmitted TEXT NOT NULL,
      submittedBy TEXT,
      submittedByEmail TEXT,
      dateApproved TEXT,
      dateDenied TEXT,
      denialReason TEXT,
      revisionRequested TEXT,
      revisionNotes TEXT,
      dateArchived TEXT
    )
  ''');

    // Add indexes for frequently queried fields
    await db.execute('CREATE INDEX idx_budgets_status ON budgets(status)');
    await db.execute(
      'CREATE INDEX idx_budgets_submitted_by ON budgets(submittedBy)',
    );
    await db.execute(
      'CREATE INDEX idx_budgets_date_submitted ON budgets(dateSubmitted)',
    );

    // Create logs table with indexes
    await db.execute('''
    CREATE TABLE logs(
      id TEXT PRIMARY KEY,
      description TEXT NOT NULL,
      timestamp TEXT NOT NULL,
      type TEXT NOT NULL,
      user TEXT NOT NULL,
      ip TEXT
    )
  ''');

    // Add indexes for logs
    await db.execute('CREATE INDEX idx_logs_timestamp ON logs(timestamp)');
    await db.execute('CREATE INDEX idx_logs_type ON logs(type)');
    await db.execute('CREATE INDEX idx_logs_user ON logs(user)');
  }

  // Users Operations
  Future<List<Map<String, dynamic>>> getUsers() async {
    Database db = await database;
    // Order by status (Active first) and then by name
    return await db.query('users', orderBy: 'status = "Inactive", name ASC');
  }

  Future<Map<String, dynamic>?> getUserById(String id) async {
    Database db = await database;
    List<Map<String, dynamic>> results = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [id],
    );

    return results.isNotEmpty ? results.first : null;
  }

  Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    if (email.isEmpty) {
      print('Error: Email cannot be empty');
      return null;
    }

    try {
      Database db = await database;
      List<Map<String, dynamic>> results = await db.query(
        'users',
        where: 'email = ?',
        whereArgs: [email],
        limit: 1, // Limit to 1 result for better performance
      );

      return results.isNotEmpty ? results.first : null;
    } catch (e) {
      print('Error in getUserByEmail: $e');
      return null;
    }
  }

  Future<int> insertUser(Map<String, dynamic> user) async {
    Database db = await database;
    return await db.insert('users', user);
  }

  Future<int> updateUser(Map<String, dynamic> user) async {
    Database db = await database;
    return await db.update(
      'users',
      user,
      where: 'id = ?',
      whereArgs: [user['id']],
    );
  }

  Future<int> updateUserStatus(String id, String status) async {
    Database db = await database;
    return await db.update(
      'users',
      {'status': status},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteUser(String id) async {
    Database db = await database;

    // First check if user exists
    List<Map<String, dynamic>> results = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (results.isEmpty) {
      return 0; // User not found
    }

    // Delete the user
    return await db.delete('users', where: 'id = ?', whereArgs: [id]);
  }

  // Budgets Operations
  Future<List<Map<String, dynamic>>> getBudgets({
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      Database db = await database;
      return await db.query(
        'budgets',
        orderBy: 'dateSubmitted DESC',
        limit: limit,
        offset: offset,
      );
    } catch (e) {
      print('Error in getBudgets: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getBudgetsByStatus(String status) async {
    Database db = await database;
    return await db.query(
      'budgets',
      where: 'status = ?',
      whereArgs: [status],
      orderBy: 'dateSubmitted DESC',
    );
  }

  Future<Map<String, dynamic>?> getBudgetById(String id) async {
    Database db = await database;
    List<Map<String, dynamic>> results = await db.query(
      'budgets',
      where: 'id = ?',
      whereArgs: [id],
    );

    return results.isNotEmpty ? results.first : null;
  }

  Future<int> insertBudget(Map<String, dynamic> budget) async {
    Database db = await database;
    return await db.insert('budgets', budget);
  }

  Future<int> updateBudget(Map<String, dynamic> budget) async {
    Database db = await database;
    return await db.update(
      'budgets',
      budget,
      where: 'id = ?',
      whereArgs: [budget['id']],
    );
  }

  Future<int> updateBudgetStatus(
    String id,
    Map<String, dynamic> updateData,
  ) async {
    Database db = await database;
    return await db.update(
      'budgets',
      updateData,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteBudget(String id) async {
    Database db = await database;
    return await db.delete('budgets', where: 'id = ?', whereArgs: [id]);
  }

  // Logs Operations
  Future<List<Map<String, dynamic>>> getLogs({
    String? type,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      Database db = await database;

      if (type != null && type.isNotEmpty) {
        return await db.query(
          'logs',
          where: 'type = ?',
          whereArgs: [type],
          orderBy: 'timestamp DESC',
          limit: limit,
          offset: offset,
        );
      }

      return await db.query(
        'logs',
        orderBy: 'timestamp DESC',
        limit: limit,
        offset: offset,
      );
    } catch (e) {
      print('Error in getLogs: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getLogsByType(String type) async {
    Database db = await database;
    return await db.query(
      'logs',
      where: 'type = ?',
      whereArgs: [type],
      orderBy: 'timestamp DESC',
    );
  }

  Future<int> insertLog(Map<String, dynamic> log) async {
    Database db = await database;
    return await db.insert('logs', log);
  }

  // Get users by role
  Future<List<Map<String, dynamic>>> getUsersByRole(String role) async {
    Database db = await database;
    return await db.query(
      'users',
      where: 'role = ?',
      whereArgs: [role],
      orderBy: 'name ASC',
    );
  }

  // Get users by status
  Future<List<Map<String, dynamic>>> getUsersByStatus(String status) async {
    Database db = await database;
    return await db.query(
      'users',
      where: 'status = ?',
      whereArgs: [status],
      orderBy: 'name ASC',
    );
  }
}
