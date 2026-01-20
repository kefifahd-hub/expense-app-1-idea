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
      version: 2, // Incremented version to trigger migration
      onCreate: (db, version) async {
        // ---------------- EXPENSES
        await db.execute('''
          CREATE TABLE expenses (
            id TEXT PRIMARY KEY,
            date TEXT NOT NULL,
            vendor TEXT NOT NULL,
            category TEXT NOT NULL,
            client TEXT NOT NULL,
            type TEXT NOT NULL DEFAULT 'Business',
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

        // ---------------- CLIENTS
        await db.execute('''
          CREATE TABLE clients (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            scope TEXT NOT NULL
          )
        ''');

        // ---------------- REPORTS
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
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Migration from version 1 to 2
          // Add DEFAULT value to type column for existing databases
          try {
            // SQLite doesn't support ALTER COLUMN, so we need to:
            // 1. Create new table with default
            // 2. Copy data
            // 3. Drop old table
            // 4. Rename new table
            
            await db.execute('''
              CREATE TABLE expenses_new (
                id TEXT PRIMARY KEY,
                date TEXT NOT NULL,
                vendor TEXT NOT NULL,
                category TEXT NOT NULL,
                client TEXT NOT NULL,
                type TEXT NOT NULL DEFAULT 'Business',
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

            // Copy existing data, deriving type from scope
            await db.execute('''
              INSERT INTO expenses_new 
              SELECT 
                id, date, vendor, category, client,
                CASE 
                  WHEN type IS NULL OR type = '' THEN 
                    CASE scope 
                      WHEN 'Professional' THEN 'Business'
                      WHEN 'Private' THEN 'Personal'
                      ELSE 'Business'
                    END
                  ELSE type
                END as type,
                scope, currency, amount, receipt_path, report_id, report_name,
                reimbursable, reimbursement_status, reimbursed_amount_eur,
                reimbursement_date, reimbursement_payer, reimbursement_reference
              FROM expenses
            ''');

            await db.execute('DROP TABLE expenses');
            await db.execute('ALTER TABLE expenses_new RENAME TO expenses');
          } catch (e) {
            print('Migration error: $e');
            // If migration fails, the table might not exist yet (fresh install)
          }
        }
      },
    );
  }

  // ============================================================
  // EXPENSES
  // ============================================================

  Future<void> insertExpense(Map<String, dynamic> row) async {
    final db = await database;
    
    // Ensure type is set based on scope if not provided
    if (!row.containsKey('type') || row['type'] == null || row['type'] == '') {
      row['type'] = (row['scope'] == 'Professional') ? 'Business' : 'Personal';
    }
    
    await db.insert('expenses', row);
  }

  Future<void> updateExpense(String id, Map<String, dynamic> updates) async {
    final db = await database;
    
    // If scope is being updated but type is not, update type accordingly
    if (updates.containsKey('scope') && !updates.containsKey('type')) {
      updates['type'] = (updates['scope'] == 'Professional') ? 'Business' : 'Personal';
    }
    
    await db.update(
      'expenses',
      updates,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteExpense(String id) async {
    final db = await database;
    await db.delete(
      'expenses',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> getAllExpenses() async {
    final db = await database;
    return await db.query('expenses', orderBy: 'date DESC');
  }

  // ============================================================
  // CLIENTS
  // ============================================================

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

  // ============================================================
  // REPORTS
  // ============================================================

  /// Draft reports for a Professional client (used in Add/Edit Expense)
  Future<List<Map<String, dynamic>>> getReportsForClient(String clientId) async {
    final db = await database;
    return await db.query(
      'reports',
      where: 'client_id = ? AND scope = ? AND status = ?',
      whereArgs: [clientId, 'Professional', 'Draft'],
      orderBy: 'period_year DESC, period_number DESC',
    );
  }

  /// Reports overview with totals (used in Home screen)
  Future<List<Map<String, dynamic>>> getReportsWithTotals({
    required String scope,
    required String status,
  }) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT
        r.*,
        COUNT(e.id) AS expense_count,
        COALESCE(SUM(e.amount), 0) AS total_amount
      FROM reports r
      LEFT JOIN expenses e ON e.report_id = r.id
      WHERE r.scope = ? AND r.status = ?
      GROUP BY r.id
      ORDER BY r.period_year DESC, r.period_number DESC
    ''', [scope, status]);
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

  Future<void> updateReportStatus(String reportId, String status) async {
    final db = await database;
    await db.update(
      'reports',
      {'status': status},
      where: 'id = ?',
      whereArgs: [reportId],
    );
  }

  /// Auto-create / reuse PRIVATE monthly report
  Future<Map<String, dynamic>> getOrCreatePrivateMonthlyReport({
    required String clientId,
    required String clientName,
    required int year,
    required int month,
  }) async {
    final db = await database;
    final periodKey = '$year-${month.toString().padLeft(2, '0')}';

    final existing = await db.query(
      'reports',
      where: 'scope = ? AND client_id = ? AND period_key = ? AND status = ?',
      whereArgs: ['Private', clientId, periodKey, 'Draft'],
      limit: 1,
    );

    if (existing.isNotEmpty) return existing.first;

    final id =
        'pri_${clientId}_${periodKey}_${DateTime.now().millisecondsSinceEpoch}';

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

    final created = await db.query(
      'reports',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    return created.first;
  }

  /// Backward-compatible alias (used by ExpenseStore)
  Future<List<Map<String, dynamic>>> getExpenses() async {
    return getAllExpenses();
  }

  /// Backward-compatible alias used by older screens
  Future<List<Map<String, dynamic>>> getDraftReportsForClient(String clientId) async {
    return getReportsForClient(clientId);
  }
}