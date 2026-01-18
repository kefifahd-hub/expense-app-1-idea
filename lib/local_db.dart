import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class LocalDb {
  static final LocalDb instance = LocalDb._internal();
  static Database? _database;

  LocalDb._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'expense_app.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // Expenses table
        await db.execute('''
          CREATE TABLE expenses (
            id TEXT PRIMARY KEY,
            date TEXT NOT NULL,
            vendor TEXT NOT NULL,
            category TEXT NOT NULL,
            client TEXT NOT NULL,
            type TEXT NOT NULL,
            scope TEXT NOT NULL,
            currency TEXT NOT NULL,
            amount REAL NOT NULL,
            receipt_path TEXT,
            report_id TEXT,
            report_name TEXT,
            reimbursable INTEGER DEFAULT 0,
            reimbursement_status TEXT DEFAULT 'Not Submitted',
            reimbursed_amount_eur REAL DEFAULT 0.0,
            reimbursement_date TEXT,
            reimbursement_payer TEXT,
            reimbursement_reference TEXT
          )
        ''');

        // Clients table
        await db.execute('''
          CREATE TABLE clients (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            scope TEXT NOT NULL
          )
        ''');

        // Reports table
        await db.execute('''
          CREATE TABLE reports (
            id TEXT PRIMARY KEY,
            client_id TEXT NOT NULL,
            client_name TEXT NOT NULL,
            name TEXT NOT NULL,
            scope TEXT NOT NULL,
            status TEXT NOT NULL,
            period_type TEXT NOT NULL,
            period_year INTEGER NOT NULL,
            period_number INTEGER NOT NULL,
            period_key TEXT NOT NULL
          )
        ''');
      },
    );
  }

  // Expense operations
  Future<void> insertExpense(Map<String, dynamic> expense) async {
    final db = await database;
    await db.insert('expenses', expense);
  }

  Future<List<Map<String, dynamic>>> getExpenses() async {
    final db = await database;
    return await db.query('expenses', orderBy: 'date DESC');
  }

  Future<void> updateExpense(String id, Map<String, dynamic> updates) async {
    final db = await database;
    await db.update(
      'expenses',
      updates,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteExpense(String id) async {
    final db = await database;
    await db.delete('expenses', where: 'id = ?', whereArgs: [id]);
  }

  // Client operations
  Future<List<Map<String, dynamic>>> getClients(String scope) async {
    final db = await database;
    return await db.query(
      'clients',
      where: 'scope = ?',
      whereArgs: [scope],
      orderBy: 'name ASC',
    );
  }

  Future<void> insertClient({
    required String id,
    required String name,
    required String scope,
  }) async {
    final db = await database;
    await db.insert('clients', {
      'id': id,
      'name': name,
      'scope': scope,
    });
  }

  // Report operations
  Future<List<Map<String, dynamic>>> getReportsForClient(String clientId) async {
    final db = await database;
    return await db.query(
      'reports',
      where: 'client_id = ? AND status = ?',
      whereArgs: [clientId, 'Draft'],
      orderBy: 'period_year DESC, period_number DESC',
    );
  }

  Future<void> insertReport({
    required String id,
    required String clientId,
    required String clientName,
    required String name,
    required String scope,
    required String status,
    required String periodType,
    required int periodYear,
    required int periodNumber,
    required String periodKey,
  }) async {
    final db = await database;
    await db.insert('reports', {
      'id': id,
      'client_id': clientId,
      'client_name': clientName,
      'name': name,
      'scope': scope,
      'status': status,
      'period_type': periodType,
      'period_year': periodYear,
      'period_number': periodNumber,
      'period_key': periodKey,
    });
  }

  Future<Map<String, dynamic>> getOrCreatePrivateMonthlyReport({
    required String clientId,
    required String clientName,
    required int year,
    required int month,
  }) async {
    final db = await database;
    final periodKey = '$year-${month.toString().padLeft(2, '0')}';

    // 1) Try to find existing draft report
    final existing = await db.query(
      'reports',
      where: 'scope = ? AND client_id = ? AND period_key = ? AND status = ?',
      whereArgs: ['Private', clientId, periodKey, 'Draft'],
      limit: 1,
    );

    if (existing.isNotEmpty) return existing.first;

    // 2) Create new private monthly report
    final id = 'pri_${clientId}_${periodKey}_${DateTime.now().millisecondsSinceEpoch}';

    await insertReport(
      id: id,
      clientId: clientId,
      clientName: clientName,
      name: '$clientName $periodKey',
      scope: 'Private',
      status: 'Draft',
      periodType: 'MONTH',
      periodYear: year,
      periodNumber: month,
      periodKey: periodKey,
    );

    // 3) Return newly created report
    final created = await db.query(
      'reports',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    return created.first;
  }
}