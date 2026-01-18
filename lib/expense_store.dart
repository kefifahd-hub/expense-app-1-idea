import 'package:flutter/foundation.dart';
import 'local_db.dart';

class Expense {
  final String id;
  final DateTime date;
  final String vendor;
  final String category;

  // display name (snapshot)
  final String client;

  // Business / Personal
  final String type;

  // NEW: Professional / Private
  final String scope;

  final String currency;
  final double amount;
  final String? receiptPath;

  // NEW: report link (professional only)
  final String? reportId;
  final String? reportName;

  // reimbursement fields
  final bool reimbursable;
  final String reimbursementStatus;
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
    required this.scope,
    required this.currency,
    required this.amount,
    this.receiptPath,
    this.reportId,
    this.reportName,
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
          id: r['id'] as String,
          date: DateTime.parse(r['date'] as String),
          vendor: (r['vendor'] ?? '') as String,
          category: (r['category'] ?? '') as String,
          client: (r['client'] ?? '') as String,
          type: (r['type'] ?? 'Business') as String,
          scope: (r['scope'] ??
                  (((r['type'] ?? 'Business') == 'Business')
                      ? 'Professional'
                      : 'Private')) as String,
          currency: (r['currency'] ?? 'EUR') as String,
          amount: (r['amount'] as num).toDouble(),
          receiptPath: r['receipt_path'] as String?,
          reportId: r['report_id'] as String?,
          reportName: r['report_name'] as String?,
          reimbursable: (r['reimbursable'] ?? 0) == 1,
          reimbursementStatus:
              (r['reimbursement_status'] ?? "Not Submitted") as String,
          reimbursedAmountEur:
              ((r['reimbursed_amount_eur'] ?? 0) as num).toDouble(),
          reimbursementDate: r['reimbursement_date'] == null
              ? null
              : DateTime.tryParse(r['reimbursement_date'] as String),
          reimbursementPayer: r['reimbursement_payer'] as String?,
          reimbursementReference: r['reimbursement_reference'] as String?,
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
