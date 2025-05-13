import 'dart:async';
import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

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
    return await openDatabase(path, version: 1, onCreate: _createDb);
  }

  Future<void> _createDb(Database db, int version) async {
    // Create users table
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

    // Create budgets table
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

    // Create logs table
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
    Database db = await database;
    List<Map<String, dynamic>> results = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email],
    );

    return results.isNotEmpty ? results.first : null;
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
  Future<List<Map<String, dynamic>>> getBudgets() async {
    Database db = await database;
    return await db.query('budgets', orderBy: 'dateSubmitted DESC');
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
  Future<List<Map<String, dynamic>>> getLogs() async {
    Database db = await database;
    return await db.query('logs', orderBy: 'timestamp DESC');
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
