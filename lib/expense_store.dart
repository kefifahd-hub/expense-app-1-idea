import 'package:flutter/foundation.dart';
import 'local_db.dart';

class Expense {
  final String id;
  final DateTime date;
  final String vendor;
  final String category;
  final String client;
  final String type;
  final String currency;
  final double amount;
  final String? receiptPath;

  // NEW reimbursement fields
  final bool reimbursable;
  final String reimbursementStatus; // Not Submitted / Submitted / Partially Reimbursed / Reimbursed / Rejected
  final double reimbursedAmountEur;
  final DateTime? reimbursementDate;
  final String? reimbursementPayer;
  final String? reimbursementReference;

  Expense({
    required this.id,
    required this.date,
    required this.vendor,
    required this.category,
    required this.client,
    required this.type,
    required this.currency,
    required this.amount,
    this.receiptPath,

    this.reimbursable = false,
    this.reimbursementStatus = "Not Submitted",
    this.reimbursedAmountEur = 0,
    this.reimbursementDate,
    this.reimbursementPayer,
    this.reimbursementReference,
  });
}

class ExpenseStore extends ChangeNotifier {
  final List<Expense> _items = [];

  List<Expense> get items => List.unmodifiable(_items);

  Future<void> loadFromDb() async {
    final rows = await LocalDb.instance.getExpenses();
    _items.clear();
    for (final r in rows) {
      _items.add(
  Expense(
    id: r['id'],
    date: DateTime.parse(r['date']),
    vendor: r['vendor'],
    category: r['category'],
    client: r['client'],
    type: r['type'],
    currency: r['currency'],
    amount: (r['amount'] as num).toDouble(),
    receiptPath: r['receipt_path'],
    reimbursable: (r['reimbursable'] ?? 0) == 1,
    reimbursementStatus: (r['reimbursement_status'] ?? "Not Submitted") as String,
    reimbursedAmountEur: ((r['reimbursed_amount_eur'] ?? 0) as num).toDouble(),
    reimbursementDate: r['reimbursement_date'] == null
        ? null
        : DateTime.tryParse(r['reimbursement_date']),
    reimbursementPayer: r['reimbursement_payer'],
    reimbursementReference: r['reimbursement_reference'],
  ),
);
    }
    notifyListeners();
    
  }

  void add(Expense e) {
    _items.insert(0, e);
    notifyListeners();
  }
}

final expenseStore = ExpenseStore();
