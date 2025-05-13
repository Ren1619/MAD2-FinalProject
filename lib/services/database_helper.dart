import 'dart:async';
import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../utils/uuid_generator.dart';
import '../models/company_model.dart';

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

    var db = await openDatabase(
      path,
      version: 2,
      onCreate: _createDb,
      onUpgrade: _onUpgrade,
    );
    return db;
  }

  Future<void> _createDb(Database db, int version) async {
    // Create companies table
    await db.execute('''
    CREATE TABLE companies(
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      email TEXT NOT NULL,
      phone TEXT,
      address TEXT,
      city TEXT,
      state TEXT,
      zipcode TEXT,
      website TEXT,
      size TEXT,
      industry TEXT,
      createdAt TEXT NOT NULL
    )
  ''');

    // Add index for email lookup
    await db.execute('CREATE INDEX idx_companies_email ON companies(email)');

    // Create users table with company reference
    await db.execute('''
    CREATE TABLE users(
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      email TEXT NOT NULL,
      role TEXT NOT NULL,
      status TEXT NOT NULL,
      createdAt TEXT NOT NULL,
      companyId TEXT,
      phone TEXT,
      enableNotifications INTEGER DEFAULT 1,
      FOREIGN KEY (companyId) REFERENCES companies(id)
    )
  ''');

    // Add indexes for frequently queried fields
    await db.execute('CREATE INDEX idx_users_email ON users(email)');
    await db.execute('CREATE INDEX idx_users_status ON users(status)');
    await db.execute('CREATE INDEX idx_users_role ON users(role)');
    await db.execute('CREATE INDEX idx_users_company ON users(companyId)');

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
      dateArchived TEXT,
      companyId TEXT,
      FOREIGN KEY (companyId) REFERENCES companies(id)
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
    await db.execute('CREATE INDEX idx_budgets_company ON budgets(companyId)');

    // Create logs table with indexes
    await db.execute('''
    CREATE TABLE logs(
      id TEXT PRIMARY KEY,
      description TEXT NOT NULL,
      timestamp TEXT NOT NULL,
      type TEXT NOT NULL,
      user TEXT NOT NULL,
      ip TEXT,
      companyId TEXT,
      FOREIGN KEY (companyId) REFERENCES companies(id)
    )
  ''');

    // Add indexes for logs
    await db.execute('CREATE INDEX idx_logs_timestamp ON logs(timestamp)');
    await db.execute('CREATE INDEX idx_logs_type ON logs(type)');
    await db.execute('CREATE INDEX idx_logs_user ON logs(user)');
    await db.execute('CREATE INDEX idx_logs_company ON logs(companyId)');
  }

  // Handle database upgrades
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add companies table if upgrading from version 1
      await db.execute('''
      CREATE TABLE companies(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        email TEXT NOT NULL,
        phone TEXT,
        address TEXT,
        city TEXT,
        state TEXT,
        zipcode TEXT,
        website TEXT,
        size TEXT,
        industry TEXT,
        createdAt TEXT NOT NULL
      )
    ''');

      await db.execute('CREATE INDEX idx_companies_email ON companies(email)');

      // Add company ID to users table
      await db.execute('''
      ALTER TABLE users ADD COLUMN companyId TEXT;
      ALTER TABLE users ADD COLUMN phone TEXT;
      ALTER TABLE users ADD COLUMN enableNotifications INTEGER DEFAULT 1;
    ''');

      // Add company ID to budgets table
      await db.execute('ALTER TABLE budgets ADD COLUMN companyId TEXT;');

      // Add company ID to logs table
      await db.execute('ALTER TABLE logs ADD COLUMN companyId TEXT;');

      // Add necessary indexes
      await db.execute('CREATE INDEX idx_users_company ON users(companyId)');
      await db.execute(
        'CREATE INDEX idx_budgets_company ON budgets(companyId)',
      );
      await db.execute('CREATE INDEX idx_logs_company ON logs(companyId)');
    }
  }

  // Company operations
  Future<Map<String, dynamic>?> getCompanyById(String id) async {
    Database db = await database;
    List<Map<String, dynamic>> results = await db.query(
      'companies',
      where: 'id = ?',
      whereArgs: [id],
    );

    return results.isNotEmpty ? results.first : null;
  }

  Future<Map<String, dynamic>?> getCompanyByEmail(String email) async {
    Database db = await database;
    List<Map<String, dynamic>> results = await db.query(
      'companies',
      where: 'email = ?',
      whereArgs: [email],
    );

    return results.isNotEmpty ? results.first : null;
  }

  Future<List<Map<String, dynamic>>> getAllCompanies() async {
    Database db = await database;
    return await db.query('companies', orderBy: 'name ASC');
  }

  Future<String> insertCompany(Company company) async {
    Database db = await database;

    // Generate a new UUID for the company if not provided
    String companyId =
        company.id.isEmpty ? UuidGenerator.generateUuid() : company.id;

    // Create a map with the company ID
    Map<String, dynamic> companyMap = company.toMap();
    companyMap['id'] = companyId;

    await db.insert('companies', companyMap);
    return companyId;
  }

  Future<int> updateCompany(Company company) async {
    Database db = await database;
    return await db.update(
      'companies',
      company.toMap(),
      where: 'id = ?',
      whereArgs: [company.id],
    );
  }

  Future<int> deleteCompany(String id) async {
    Database db = await database;
    return await db.delete('companies', where: 'id = ?', whereArgs: [id]);
  }

  // Users Operations with company support
  Future<List<Map<String, dynamic>>> getUsers() async {
    Database db = await database;
    // Order by status (Active first) and then by name
    return await db.query('users', orderBy: 'status = "Inactive", name ASC');
  }

  Future<List<Map<String, dynamic>>> getUsersByCompany(String companyId) async {
    Database db = await database;
    return await db.query(
      'users',
      where: 'companyId = ?',
      whereArgs: [companyId],
      orderBy: 'status = "Inactive", name ASC',
    );
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

  // Budgets Operations with company support
  Future<List<Map<String, dynamic>>> getBudgets({
    int limit = 20,
    int offset = 0,
    String? companyId,
  }) async {
    try {
      Database db = await database;

      if (companyId != null) {
        return await db.query(
          'budgets',
          where: 'companyId = ?',
          whereArgs: [companyId],
          orderBy: 'dateSubmitted DESC',
          limit: limit,
          offset: offset,
        );
      }

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

  Future<List<Map<String, dynamic>>> getBudgetsByStatus(
    String status, {
    String? companyId,
  }) async {
    Database db = await database;

    if (companyId != null) {
      return await db.query(
        'budgets',
        where: 'status = ? AND companyId = ?',
        whereArgs: [status, companyId],
        orderBy: 'dateSubmitted DESC',
      );
    }

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

  // Logs Operations with company support
  Future<List<Map<String, dynamic>>> getLogs({
    String? type,
    int limit = 50,
    int offset = 0,
    String? companyId,
  }) async {
    try {
      Database db = await database;

      if (type != null && type.isNotEmpty && companyId != null) {
        return await db.query(
          'logs',
          where: 'type = ? AND companyId = ?',
          whereArgs: [type, companyId],
          orderBy: 'timestamp DESC',
          limit: limit,
          offset: offset,
        );
      } else if (type != null && type.isNotEmpty) {
        return await db.query(
          'logs',
          where: 'type = ?',
          whereArgs: [type],
          orderBy: 'timestamp DESC',
          limit: limit,
          offset: offset,
        );
      } else if (companyId != null) {
        return await db.query(
          'logs',
          where: 'companyId = ?',
          whereArgs: [companyId],
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

  Future<List<Map<String, dynamic>>> getLogsByType(
    String type, {
    String? companyId,
  }) async {
    Database db = await database;

    if (companyId != null) {
      return await db.query(
        'logs',
        where: 'type = ? AND companyId = ?',
        whereArgs: [type, companyId],
        orderBy: 'timestamp DESC',
      );
    }

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
  Future<List<Map<String, dynamic>>> getUsersByRole(
    String role, {
    String? companyId,
  }) async {
    Database db = await database;

    if (companyId != null) {
      return await db.query(
        'users',
        where: 'role = ? AND companyId = ?',
        whereArgs: [role, companyId],
        orderBy: 'name ASC',
      );
    }

    return await db.query(
      'users',
      where: 'role = ?',
      whereArgs: [role],
      orderBy: 'name ASC',
    );
  }

  // Get users by status
  Future<List<Map<String, dynamic>>> getUsersByStatus(
    String status, {
    String? companyId,
  }) async {
    Database db = await database;

    if (companyId != null) {
      return await db.query(
        'users',
        where: 'status = ? AND companyId = ?',
        whereArgs: [status, companyId],
        orderBy: 'name ASC',
      );
    }

    return await db.query(
      'users',
      where: 'status = ?',
      whereArgs: [status],
      orderBy: 'name ASC',
    );
  }
}
