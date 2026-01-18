import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class LocalDb {
  static final LocalDb instance = LocalDb._();
  static Database? _db;

  LocalDb._();
Future<void> updateExpense(String id, Map<String, dynamic> data) async {
  final db = await database;
  await db.update('expenses', data, where: 'id = ?', whereArgs: [id]);
}

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = join(dir.path, 'expenses.db');

return openDatabase(
  path,
  version: 2,
  onCreate: (db, version) async {
    await db.execute('''
      CREATE TABLE expenses (
        id TEXT PRIMARY KEY,
        date TEXT,
        vendor TEXT,
        category TEXT,
        client TEXT,
        type TEXT,
        currency TEXT,
        amount REAL,
        receipt_path TEXT,
        reimbursable INTEGER,
        reimbursement_status TEXT,
        reimbursed_amount_eur REAL,
        reimbursement_date TEXT,
        reimbursement_payer TEXT,
        reimbursement_reference TEXT
      )
    ''');
  },
  onUpgrade: (db, oldVersion, newVersion) async {
    if (oldVersion < 2) {
      await db.execute("ALTER TABLE expenses ADD COLUMN reimbursable INTEGER;");
      await db.execute("ALTER TABLE expenses ADD COLUMN reimbursement_status TEXT;");
      await db.execute("ALTER TABLE expenses ADD COLUMN reimbursed_amount_eur REAL;");
      await db.execute("ALTER TABLE expenses ADD COLUMN reimbursement_date TEXT;");
      await db.execute("ALTER TABLE expenses ADD COLUMN reimbursement_payer TEXT;");
      await db.execute("ALTER TABLE expenses ADD COLUMN reimbursement_reference TEXT;");
    }
  },
);
  }

  Future<void> insertExpense(Map<String, dynamic> data) async {
    final db = await database;
    await db.insert('expenses', data);
  }

  Future<List<Map<String, dynamic>>> getExpenses() async {
    final db = await database;
    return db.query('expenses', orderBy: 'date DESC');
  }
}
